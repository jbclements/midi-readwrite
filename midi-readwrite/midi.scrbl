#lang scribble/manual

@(require scribble/manual)

@title{Racket MIDI reader}

@author[(author+email "John Clements" 
                      "clements@racket-lang.org")]

@(require (for-label racket "main.rkt"))

@defmodule[midi-readwrite]{This package can read and parse MIDI files written in the 
"Standard MIDI File" format, also known as "SMF", and usually
appearing in files ending with ".mid".

The output of this parser is currently ad-hoc but 
non-ambiguous; the best way to understand it is to 
read the source in "midi-structs.rkt"


@defproc[(midi-file-parse [path path-string?]) (listof list?)]{
 Given a path, parse the file as a standard MIDI file.}

@defproc[(midi-port-parse [port port?]) (listof list?)]{
 Given a port searchable with @racket[file-position], parse
 the content as a standard MIDI file.}

I bet there's a nice way to format this....

@defstruct[MIDIFile ([format MIDIFormat] 
                     [division MIDIDivision]
                     [tracks (listof MIDITrack)])]{
 Represents a MIDI file.
}

Too lazy to format the rest of these right now....

@verbatim{
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

}

}

