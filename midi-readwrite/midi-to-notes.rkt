#lang racket

;; for clients that just want a simple list of notes, this takes a MIDI file
;; and discards all information except for the notes. The resulting list is
;; sorted by start time. All times are expressed in "ticks"; the length of a
;; tick may vary.

(require "midi-structs.rkt")

(provide MIDIFile->notelist
         (struct-out note))


(define (MIDIFile->notelist file)
  (sort 
   (apply append
          (map messages->notes (MIDIFile-tracks file)))
   time<?))

;; a note is (note midi-note-num ticks ticks)
;; representing a note at the given note-number, starting at
;; "time" and lasting for "duration"
(struct note (pitch time duration) #:transparent)

;; given a list of channel-messages, return a list of notes.
(define (messages->notes channel-messages #:careful [careful? #f])
  ;; keep a hash table of the notes currently playing
  (let loop ([msgs channel-messages] [note-playing-table (hash)])
    (define (stop-playing-note note-num frames)
      (match (hash-ref note-playing-table note-num #f)
        [#f 
         (if careful?
             (error
              'parse-messages
              "stopped playing but there was no note playing: ~s"
              (first msgs))
             ;; ended a note that wasn't playing... ignore it.
             (loop (rest msgs) note-playing-table))]
        [note-playing-start
         (cons (note note-num
                     note-playing-start
                     (- frames note-playing-start))
               (loop (rest msgs) 
                     (hash-remove note-playing-table note-num)))]))
    (cond [(empty? msgs)
           (match (hash-count note-playing-table)
             [0 empty]
             [other (error
                     'parse-messages
                     "notes are still playing: ~s" (hash->list note-playing-table))])]
          [else
           (match (first msgs)
             [(list frames (struct ChannelMessage ('note-on channel info)))
              (match info
                ;; the "play with velocity 0" seems to be the standard way
                ;; of signalling a note end.
                [(list note-num 0)
                 (stop-playing-note note-num frames)]
                ;; nonzero velocities correspond to note starts.
                [(list note-num velocity) ;; ignoring velocity for now....
                 (match (hash-ref note-playing-table note-num #f)
                   [#f (loop (rest msgs) (hash-set note-playing-table note-num frames))]
                   [other 
                    (if careful?
                        (error 'messages->notelist
                               "already playing: ~s" (first msgs))
                        ;; note was already playing... probably a change in velocity.
                        ;; just ignore it! :)
                        (loop (rest msgs) note-playing-table))])])]
             ;; WARNING! UNTESTED CODE:
             ;; haven't actually seen one of these in the wild....
             [(list frames (struct ChannelMessage ('note-off channel info)))
              (match info
                [(list note-num _1) (stop-playing-note note-num frames)])]
             ;; not a note-on or note-off message, ignore it:
             [(list frames (struct ChannelMessage (other-symbol _1 _2)))
              (loop (rest msgs) note-playing-table)]
             ;; not a channel message, ignore it:
             [else
              (loop (rest msgs) note-playing-table)])])))


(define (time<? a b)
  (< (note-time a) (note-time b)))


