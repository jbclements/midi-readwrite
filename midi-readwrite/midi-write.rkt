#lang typed/racket/base

(require "midi-structs.rkt"
         typed/rackunit)


(: midi-file-write (MIDIFile Path-String -> Void))
(define (midi-file-write midi-file path)
  (call-with-output-file path
    (lambda: ([port : Output-Port])
      (midi-port-write midi-file port))))

(: midi-port-write (MIDIFile Output-Port -> Void))
(define (midi-port-write midi-file port)
  
  (void))

#;(: message->bytes (MIDIMessage -> Bytes))
#;(define (message->bytes message)
  (cond 
    [(MetaMessage? message)
     ]))

(: variable-length->bytes (Bytes -> Bytes))
(define (variable-length->bytes content)
  (bytes-append 
   (len/encoded (bytes-length content))
   content))

(: len/encoded (Natural -> Bytes))
(define (len/encoded n)
  (list->bytes 
   (reverse
    (let loop ([first? #t] [n n])
      (define bottom-7-bits (bitwise-and #x7f n))
      (define with-bit (cond [first? bottom-7-bits]
                             [else 
                              (bitwise-ior #x80 bottom-7-bits)]))
      (cond [(= n 0) null]
            [else
             (cons with-bit
                   (loop #f (arithmetic-shift n -7)))])))))

(check-equal? (len/encoded 894) #"\206\176")




(: chunk-write (Bytes Bytes Output-Port -> Void))
(define (chunk-write id content port)
  (when (not (= (bytes-length id) 4))
    (error 'chunk-write "expected an id of length 4, got: ~s" id))
  (when (< max-chunk-len (bytes-length content))
    (error 'chunk-write "can't write chunk of longer than ~s bytes, given ~s bytes"
           max-chunk-len (bytes-length content)))
  (display id port)
  (display (integer->integer-bytes (bytes-length content) 4 #f #t)
           port)
  (display content port))

(define max-chunk-len (expt 2 32))


(let ()
  (define ob (open-output-bytes))
  (chunk-write #"ohth" #"1234 1234 1234 1234 1234 " ob)
  (check-equal? (get-output-bytes ob)
                #"ohth\0\0\0\0311234 1234 1234 1234 1234 "))


