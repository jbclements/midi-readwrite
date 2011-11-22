#lang typed/racket/base


(provide MIDIFile
         #;MIDIFile-format
         #;MIDIFile-division
         #;MIDIFile-tracks
         TicksPerQuarter
         #;TicksPerQuarter?
         #;TicksPerQuarter-ticks
         SMPTE
         #;SMPTE?
         #;SMPTE-a
         #;SMPTE-b
         MetaMessage
         MetaMessage?
         MetaMessage-content
         SysexMessage
         SysexMessage?
         SysexMessage-content
         ChannelMessage
         ChannelMessage?
         ChannelMessage-kind
         ChannelMessage-channel
         ChannelMessage-operands
         MIDIFormat
         MIDIDivision
         MIDIEvent
         MIDIMessage)

(struct: MIDIFile ([format : MIDIFormat]
                   [division : MIDIDivision]
                   [tracks : (Listof MIDITrack)])
  #:transparent)

(define-type MIDIFormat (U 'multi 'single 'sequential))
(define-type MIDIDivision (U TicksPerQuarter SMPTE))
(struct: TicksPerQuarter ([ticks : Natural]) #:transparent)
(struct: SMPTE ([a : Natural] [b : Natural]) #:transparent)

(define-type MIDITrack (Listof MIDIEvent))

(define-type MIDIEvent (List Integer MIDIMessage))
(define-type MIDIMessage (U MetaMessage ChannelMessage SysexMessage))
(struct: MetaMessage ([content : Any]) #:transparent)
(struct: SysexMessage ([content : Any]) #:transparent)
(struct: ChannelMessage ([kind : MIDIKind] 
                         [channel : Byte]
                         [operands : (List Byte (U Byte False))]) 
  #:transparent)
(define-type MIDIKind Symbol)