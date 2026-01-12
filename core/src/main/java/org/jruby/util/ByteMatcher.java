/**
 * ByteMatcher - Fast byte-level pattern matching for JRuby strings
 *
 * Provides optimized algorithms for common string search patterns.
 * This is the core interface that all matchers implement.
 */
package org.jruby.util;

import org.jcodings.Encoding;

public interface ByteMatcher {

    /**
     * Find first occurrence of pattern in source bytes
     *
     * @param source the byte array to search
     * @param offset starting position in source
     * @param length number of bytes to search
     * @param enc the encoding of the source bytes
     * @return index of first match, or -1 if not found
     */
    int search(byte[] source, int offset, int length, Encoding enc);

    /**
     * Find all occurrences of pattern
     *
     * @param source the byte array to search
     * @param offset starting position in source
     * @param length number of bytes to search
     * @param enc the encoding of the source bytes
     * @return array of match indices (empty array if no matches)
     */
    int[] searchAll(byte[] source, int offset, int length, Encoding enc);

    /**
     * Check if pattern matches at specific position
     *
     * @param source the byte array to check
     * @param pos position to check for match
     * @param enc the encoding of the source bytes
     * @return true if pattern matches at pos, false otherwise
     */
    boolean matchAt(byte[] source, int pos, Encoding enc);

    /**
     * Get the pattern being matched
     *
     * @return the pattern bytes
     */
    byte[] getPattern();

    /**
     * Get the length of the pattern
     *
     * @return pattern length in bytes
     */
    int patternLength();

    /**
     * Factory method to create optimal matcher for given pattern
     *
     * @param pattern the pattern to match
     * @param enc the encoding
     * @return optimized ByteMatcher instance
     */
    static ByteMatcher create(byte[] pattern, Encoding enc) {
        if (pattern == null || pattern.length == 0) {
            throw new IllegalArgumentException("Pattern cannot be null or empty");
        }

        // Choose optimal matcher based on pattern characteristics
        if (pattern.length == 1) {
            return new SingleByteMatcher(pattern[0]);
        } else if (pattern.length <= 4) {
            // For very short patterns, naive is actually faster
            return new NaiveMatcher(pattern);
        } else {
            // For longer patterns, Boyer-Moore wins
            return new BoyerMooreMatcher(pattern);
        }
    }
}
