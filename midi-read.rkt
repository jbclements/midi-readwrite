#lang typed/racket/base

(require typed/rackunit
         "midi-structs.rkt")

(provide midi-file-parse
         midi-port-parse)


#|
(provide/contract [midi-file-parse (-> path-string?
                                       parsed-result?)]
                  [midi-port-parse (-> port?
                                       parsed-result?)])
|#

;; FILE CONSTRUCTS:
(struct: FileChunk ([id : Bytes] [len : Natural] [offset : Natural]))

;; given a path, parse the file into a list containing
;; the MIDI format, the time division, and a list of 
;; tracks, where a track contains a list of time/message
;; lists
(: midi-file-parse (Path-String -> MIDIFile))
(define (midi-file-parse path)
  (define p (open-input-file path))
  (midi-port-parse p))

;; given a port with the file-position operator, 
;; parse the file into a list containing
;; the MIDI format, the time division, and a list of 
;; tracks, where a track contains a list of time/message
;; lists
(: midi-port-parse (Input-Port -> MIDIFile))
(define (midi-port-parse port)
  (define chunks (port->chunks port))
  (when (null? chunks)
    (error 'midi-port-parse "midi file contained no chunks at all"))
  (define header-info (parse-header (car chunks) port))
  (unless (= (cadr header-info) 
             (length (cdr chunks)))
    (error 'parsing "wrong number of tracks"))
  (define tracks (map (parse-chunk port) (cdr chunks)))
  (close-input-port port)
  (MIDIFile (car header-info)
            (caddr header-info)
            tracks))

;; pick out all of the chunk locations in a file.
(: port->chunks (Input-Port -> (Listof FileChunk)))
(define (port->chunks port)
  (let: loop : (Listof FileChunk) ([offset : Natural 0])
    (define chunk (chunk-discover port offset))
    (case chunk
      [(#f) null]
      [else 
       (cons chunk (loop (+ (FileChunk-offset chunk)
                            (FileChunk-len chunk))))])))


(define header-len 6)

;; given a header chunk and a port, produce the header-info
(: parse-header (FileChunk Input-Port -> (List MIDIFormat
                                               Natural
                                               MIDIDivision)))
(define (parse-header h-chunk port)
  (unless (equal? (FileChunk-id h-chunk) #"MThd")
    (error 'parse-header "header chunk didn't have id MThd"))
  (unless (equal? (FileChunk-len h-chunk) 6)
    (error 'parse-header "header chunk didn't have length 6"))
  (define header-bytes (bytes-from-posn port 
                                        (FileChunk-offset h-chunk )
                                        6))
  (cond 
    [(eof-object? header-bytes)
     (error 'parse-header "got #<eof> while reading header")]
    [else
     (define format-bytes 
       (integer-bytes->unsigned (subbytes header-bytes 0 2)))
     (define format
       (case format-bytes
         [(0) 'single]
         [(1) 'multi]
         [(2) 'sequential]
         [else (error 'parse-header "unexpected format number: ~s"
                      format-bytes)]))
     (define num-tracks
       (integer-bytes->unsigned (subbytes header-bytes 2 4)))
     (define division-word
       (integer-bytes->unsigned (subbytes header-bytes 4 6)))
     (define division
       (cond [(= 0 (bitwise-and #x8000 division-word))
              (TicksPerQuarter 
               (bitwise-and #x7ffff division-word))]
             [else
              (SMPTE
               (bitwise-and 
                #x7f 
                (arithmetic-shift division-word -8))
               (bitwise-and #xff division-word))]))
     (list format num-tracks division)]))



;; given a port and a chunk, parse the messages in the chunk
(: parse-chunk (Input-Port -> (FileChunk -> (Listof MIDIEvent))))
(define ((parse-chunk port) a-chunk)
  (parse-messages port (FileChunk-offset a-chunk)
                  (FileChunk-len a-chunk)))



;; given a port, an offset, and a length in bytes, parse
;; the messages contained in the file at that location
(: parse-messages (Input-Port Natural Natural -> 
                              (Listof MIDIEvent)))
(define (parse-messages port offset len)
  (file-position port offset)
  (define stop-offset (+ offset len))
  (let: loop : (Listof MIDIEvent)
    ([prior-event-type-byte : (U Byte False) #f]
     [time : Natural 0])
    (cond [(<= stop-offset (file-position port))
           '()]
          [else 
           (define bundle 
             (parse-1-message port prior-event-type-byte time))
           (define new-time (car bundle))
           (define byte (cadr bundle))
           (define message (caddr bundle))
           (cons (list new-time message) (loop byte new-time))])))


;; given a port, a prior event-type-byte, and a prior time,
;; return a list containing the new time, the new event-type-byte,
;; and the new message. The second of these is necessary to support
;; the "and another of the same" style of message.
(: parse-1-message (Input-Port (U Byte False) Natural -> 
                               (List Natural (U Byte False) MIDIMessage)))
(define (parse-1-message port prior-event-type-byte prior-time)
  (define time-offset (read-variable-length port))
  (define new-time (+ prior-time time-offset))
  (define next-byte (read-non-eof-byte port))
  (define bundle
    (case next-byte
      [(#xf0) 
       (list 
        #f
        (SysexMessage
         (len-and-bytes port)))]
      [(#xff) 
       (define meta-kind (read-non-eof-byte port))
       (list 
        #f
        (MetaMessage
         (case meta-kind
           ;; just doing the ones I see....
           [(#x01) (list 'text (read-variable-length-bytes port))]
           [(#x02) (list 'copyright-notice 
                         (read-variable-length-bytes port))]
           [(#x03) (list 'sequence/track-name 
                         (read-variable-length-bytes port))]
           [(#x2f) (len-and-bytes port)
                   'end-of-track]
           [(#x51) (define content (len-and-bytes port))
                   (list 'set-tempo 
                         (integer-bytes->integer
                          (bytes-append (bytes #x00)
                                        content)
                          #f #t))]
           [(#x58) (define content (len-and-bytes port))
                   (list 'time-signature
                         (bytes->list content))]
           [(#x59) (define content (len-and-bytes port))
                   (define flats/sharps-byte (subbytes content 0 1))
                   (define major/minor
                     (case (bytes-ref content 1)
                       [(#x00) 'major]
                       [(#x01) 'minor]))
                   (list 'key-signature
                         flats/sharps-byte
                         major/minor)]
           [else
            (list 'unknown meta-kind (len-and-bytes port))]
           )))]
      [else 
       (cond [(not (= 0 (bitwise-and #x80 next-byte)))
              ;; new message
              (define channel (bitwise-and #x7 next-byte))
              (define message-nibble (high-nibble next-byte))
              (define message-kind (bits->event-type message-nibble))
              (define parameter-1 (read-non-eof-byte port))
              (define parameter-2 
                (cond [(two-byte-event? message-nibble)
                       (read-non-eof-byte port)]
                      [else #f]))
              (list next-byte
                    (ChannelMessage
                     message-kind
                     channel
                     (list parameter-1
                           parameter-2)))]
             [else
              (cond 
                [(not prior-event-type-byte)
                 (error 'parse-1-message
                        "can't continue from non-channel event")]
                [else
                 ;; running status , the midi-evt was actually parameter 1.
                 (define channel (bitwise-and #x7 prior-event-type-byte))
                 (define message-nibble (high-nibble 
                                         prior-event-type-byte))
                 (define message-kind (bits->event-type message-nibble))
                 (define parameter-1 next-byte)
                 (define parameter-2 
                   (cond [(two-byte-event? message-nibble)
                          (read-non-eof-byte port)]
                         [else #f]))
                 (list prior-event-type-byte
                       (ChannelMessage
                        message-kind
                        channel
                        (list parameter-1
                              parameter-2)))])
              ])]))
  
  (define event-type-byte (car bundle))
  (define message (cadr bundle))
  (list new-time event-type-byte message)
  )

(: high-nibble (Byte -> Byte))
(define (high-nibble b)
  (define r (arithmetic-shift b -4))
  (cond [(< 255 r) (error 'high-nibble "impossible 20111114-2")]
        [else r]))


(: two-byte-event? (Byte -> Boolean))
(define (two-byte-event? bits)
  (not (or (= bits #xc) (= bits #xd))))


(: bits->event-type (Byte -> Symbol))
(define (bits->event-type bits)
  (case bits 
    ((#x8) 'note-off)
    [(#x9) 'note-on]
    [(#xa) 'aftertouch]
    [(#xb) 'control-change]
    [(#xc) 'program-change]
    [(#xd) 'channel-aftertouch]
    [(#xe) 'pitch-bend]
    (else (error 'bits->event-type
                 "unexpected event type: ~s" bits))))


#;(define (parse-text-meta tag port)
  (list tag (len-and-bytes port)))


;; read a length and that number of bytes from a port
(: len-and-bytes : (Input-Port -> Bytes))
(define (len-and-bytes port)
  (define len (read-variable-length port))
  (define b (read-bytes len port))
  (cond [(eof-object? b)
         (error 'len-and-bytes
                "#<eof> while reading bytes")]
        [else b]))

(: read-variable-length-bytes (Input-Port -> Bytes))
(define (read-variable-length-bytes port)
  (define len (read-variable-length port))
  (define b (read-bytes len port))
  (cond [(eof-object? b)
         (error 'read-variable-length-bytes
                "got #<eof> during variable-length text")]
        [else b]))

;; read a variable-length quantity, advance the port
;; if these can be negative, I'm worried.
(: read-variable-length (Input-Port -> Natural))
(define (read-variable-length port)
  (let: loop : Natural ([so-far : Natural #x00])
    (define next-byte (read-non-eof-byte port))
    (define new-so-far (bitwise-ior 
                        (arithmetic-shift so-far 7)
                        (bitwise-and #x7f next-byte)))
    (cond [(not (= 0 (bitwise-and #x80 next-byte)))
           (loop new-so-far)]
          [else new-so-far])))


;; given a port and an offset, read the chunk info starting at that offset.
(: chunk-discover (Input-Port Natural -> (U FileChunk False)))
(define (chunk-discover port offset)
  (define bytes-in (bytes-from-posn port offset 8))
  (cond 
    [(eof-object? bytes-in) #f]
    [else
     (let* ([id (subbytes bytes-in 0 4)]
            [len (integer-bytes->unsigned (subbytes bytes-in 4 8))])
       (FileChunk id len (+ offset 8)))]))


;; bytes-from-posn : port nat nat -> bytes
;; read a piece from a file
(: bytes-from-posn (Input-Port Natural Natural -> (U Bytes EOF)))
(define (bytes-from-posn port offset len)
  (file-position port offset)
  (read-bytes len port))

;; assumes big-endian
(: integer-bytes->unsigned (Bytes -> Natural))
(define (integer-bytes->unsigned b)
  (define i (integer-bytes->integer b #f #t))
  (cond [(< i 0) (error 'integer-bytes->unsigned "impossible 20111114")]
        [else i]))

(: read-non-eof-byte (Input-Port -> Byte))
(define (read-non-eof-byte port)
  (define b (read-byte port))
  (cond [(eof-object? b) (error 'read-non-eof-byte "got #<eof>")]
        [else b]))


(check-equal? (read-variable-length
               (open-input-bytes (bytes #x00))) 0)
(check-equal? (read-variable-length 
               (open-input-bytes (bytes #x81 00))) #x80)
(check-equal? (read-variable-length
               (open-input-bytes (bytes #x81 #x80 #x80 #x00))) #x200000)