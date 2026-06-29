# frozen_string_literal: true

# Kestówv 0.5.1 — core/byte_matcher.rb
#
# Plain-Ruby byte-pattern matcher. Spiritually the same shape as
# UniversalByteMatcher/BoyerMooreMatcher on the bytematcher-experiment
# branch (org.jruby.util) — same MatchMode set, same Boyer-Moore-Horspool
# core — but that branch's Java classes were never merged into master or
# built-ins and aren't present in the installed JRuby 10.1.0.0 jar, so
# there's no Java class to call into. This is a from-scratch Ruby
# reimplementation, not a wrapper around it.
#
# Input is StringIO or String; either way the search runs against raw
# bytes (.b), not the source encoding, same "any byte sequence" stance
# the Java version took (file paths, process names, network data, ...).
#
# Namespace: Kestowv::Core::ByteMatcher
# (NOT Kestowv::Boot — that would shadow ::Boot for all kernel code.)

require 'stringio'

module Kestowv
  module Core
    module ByteMatcher

      MODES = %i[exact contains starts_with ends_with fuzzy].freeze

      # --------------------------------------------------------
      # REGISTRATION
      # Called once at boot to wire into the Boot feature registry.
      # --------------------------------------------------------

      def self.register_with_boot
        Boot.register(:core_byte_matcher)
        Boot.set_bit(:core_byte_matcher)
        self
      end

      # --------------------------------------------------------
      # FIND_FIRST — main entry point
      # source:  StringIO or String — the haystack
      # pattern: String — the needle
      # mode:    one of MODES
      # Returns the byte offset of the first match, or -1.
      # --------------------------------------------------------

      def self.find_first(source, pattern, mode: :contains)
        raise ArgumentError, "unknown mode: #{mode.inspect} (expected one of #{MODES.inspect})" unless MODES.include?(mode)

        data = bytes_from(source)
        pat  = pattern.to_s.b
        return -1 if data.empty? || pat.empty?

        case mode
        when :exact       then data == pat ? 0 : -1
        when :starts_with then data.start_with?(pat) ? 0 : -1
        when :ends_with    then data.end_with?(pat) ? data.bytesize - pat.bytesize : -1
        when :fuzzy        then boyer_moore(data.downcase, pat.downcase)
        when :contains      then boyer_moore(data, pat)
        end
      end

      # --------------------------------------------------------
      # BYTES_FROM — normalize StringIO/String input to a binary
      # String of raw bytes, leaving the source position untouched.
      # --------------------------------------------------------

      def self.bytes_from(source)
        case source
        when StringIO
          pos = source.pos
          source.rewind
          bytes = source.read.to_s.b
          source.pos = pos
          bytes
        when String
          source.b
        else
          raise ArgumentError, "ByteMatcher needs StringIO or String, got #{source.class}"
        end
      end

      # --------------------------------------------------------
      # BOYER-MOORE-HORSPOOL — O(n+m) average case bad-character search.
      # data/pat must already be binary-encoded (.b) byte strings.
      # --------------------------------------------------------

      def self.boyer_moore(data, pat)
        m = pat.bytesize
        n = data.bytesize
        return -1 if m > n

        skip = Array.new(256, m)
        (0...m).each { |i| skip[pat.getbyte(i)] = m - 1 - i }

        i = 0
        while i <= n - m
          j = m - 1
          j -= 1 while j >= 0 && pat.getbyte(j) == data.getbyte(i + j)
          return i if j < 0

          i += skip[data.getbyte(i + m - 1)]
        end

        -1
      end
      private_class_method :boyer_moore
    end
  end
end

# --------------------------------------------------------
# AUTO-REGISTER with Config::Modules
# --------------------------------------------------------
Kestowv::Config::Modules.register(
  :core_byte_matcher,
  __FILE__,
  feature:    :byte_matcher,
  depends_on: []
)
