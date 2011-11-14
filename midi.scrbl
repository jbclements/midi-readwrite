#lang scribble/manual

@(require planet/scribble)

@title{Racket MIDI reader}

@author[(author+email "John Clements" 
                      "clements@racket-lang.org")]

@(require (for-label racket
                     (this-package-in main)))

@defmodule/this-package[main]{This package can read and parse MIDI files written in the 
"Standard MIDI File" format, also known as "SMF", and usually
appearing in files ending with ".mid".

The output of this parser is currently ad-hoc but 
non-ambiguous; essentially, it's a classic "list of lists"
format.

}

@defproc[(midi-file-parse [path path-string?]) (listof list?)]{
 Given a path, parse the file as a standard MIDI file.}

@defproc[(midi-port-parse [port port?]) (listof list?)]{
 Given a port searchable with @racket[file-position], parse
 the content as a standard MIDI file.}

