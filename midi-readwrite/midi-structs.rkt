#lang typed/racket/base

;; this file defines the structures used by the library.

(provide (struct-out MIDIFile)
         (struct-out TicksPerQuarter)
         (struct-out SMPTE)
         (struct-out MetaMessage)
         (struct-out SysexMessage)
         (struct-out ChannelMessage)
         MIDITrack
         MIDIFormat
         MIDIDivision
         MIDIEvent
         MIDIMessage
         Clocks)

(define-struct: MIDIFile ([format : MIDIFormat]
                          [division : MIDIDivision]
                          [tracks : (Listof MIDITrack)])
  #:transparent)

(define-type MIDIFormat (U 'multi 'single 'sequential))
(define-type MIDIDivision (U TicksPerQuarter SMPTE))
(define-struct: TicksPerQuarter ([ticks : Clocks]) #:transparent)
(define-struct: SMPTE ([a : Natural] [b : Natural]) #:transparent)

;; hidden invariant: the events in the track must have increasing times
(define-type MIDITrack (Listof MIDIEvent))

;; Clocks absolute, relative to start of track.
(define-type MIDIEvent (List Clocks MIDIMessage))
(define-type Clocks Natural)
(define-type MIDIMessage (U MetaMessage ChannelMessage SysexMessage))
(define-struct: MetaMessage ([content : Any]) #:transparent)
(define-struct: SysexMessage ([content : Any]) #:transparent)
(define-struct: ChannelMessage ([kind : MIDIKind] 
                         [channel : Byte]
                         [operands : (List Byte (U Byte False))]) 
  #:transparent)
(define-type MIDIKind Symbol)