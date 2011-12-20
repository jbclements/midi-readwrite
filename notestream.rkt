#lang typed/racket

(require "midi-structs.rkt")

(require/typed "sort-helper.rkt"
               [sort< (All (T) (Listof T) (T -> Clocks)
                           -> (Listof T))])



(provide track->notes
         (struct-out Note)
         note-tones
         note-filter
         event-sequence->note-sequence)

(define-struct: Note ([notenum : Byte]
                      [velocity : Byte]
                      [start : Clocks]
                      [duration : Clocks]))



;; return a list of the notes in the given channel.
;; This implementation is unnecessarily n^2, but generating
;; the sounds seems to be much more expensive.
;; note that this discards all meta-messages.
(: track->notes (MIDITrack -> (Listof Note)))
(define (track->notes messages)
  (sort<
   (apply append
          (append 
           (for/list: : (Listof (Listof Note))
             ([note-num (in-range 127)])
             (cond 
               [(byte? note-num)
                (note-tones messages note-num)]
               [else 
                (error 'make-the-type-checker-happy)
                ]))))
   Note-start))


;; -> (Listof note-num start-time duration velocity)
(: note-tones (MIDITrack Byte -> (Listof Note)))
(define (note-tones message-sequence note-num)
  ((event-sequence->note-sequence note-num)
   (filter (note-filter note-num) message-sequence)))

;; given a note, produce a ((List number message) -> Boolean)
;; that returns true when the message is a channel message
;; where the note number matches
(: note-filter (Natural -> (MIDIEvent -> Boolean)))
(define ((note-filter num) time-n-message)
  (match (second time-n-message)
    [(ChannelMessage 'note-on ch (list n v)) (= n num)]
    [(ChannelMessage 'note-off ch (list n v)) (= n num)]
    [(MetaMessage 'end-of-track) #t]
    [other #f]))


;; use with a sequence of note-on-offs for a single note
;; -> (Listof start-time duration velocity)
(: event-sequence->note-sequence 
   (Byte -> (Listof MIDIEvent) -> (Listof Note)))
(define ((event-sequence->note-sequence note-num) note-on-offs)
  (match note-on-offs
    [(cons (list t1 (ChannelMessage 'note-on ch1 (list n1 vel1)))
           (cons (list t2 next-message) rest))
     (cond 
       [(false? vel1)
        (error 'event-sequence->note-sequence 
               "note-on message had no velocity field.")]
       [else
        (unless (= n1 note-num)
          (error 'event-sequence->note-sequence "expected note number ~s, got ~s"
                 note-num
                 n1))
        (cond 
          [(= vel1 0)
           ((event-sequence->note-sequence note-num)
            (cons (list t2 next-message) rest))]
          [else
           (define dur (- t2 t1))
           (cond [(< dur 0)
                  (error 'event-sequence-note-sequence
                         "out-of-order events with starting times: ~s, ~s"
                         t1 t2)]
                 [else
                  (cons (Note note-num vel1 t1 dur)
                        ((event-sequence->note-sequence note-num) 
                         (cons (list t2 next-message) rest)))])])])
     ]
    [(cons (list t1 (MetaMessage 'end-of-track)) empty)
     null]
    [(cons (list t1 (ChannelMessage 'note-off ch1 (list n1 vel1)))
           rest)
     ((event-sequence->note-sequence note-num) rest)]))