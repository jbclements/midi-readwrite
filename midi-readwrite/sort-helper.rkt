#lang racket

(provide sort<)

(define (sort< l key)
  (sort l < #:key key))