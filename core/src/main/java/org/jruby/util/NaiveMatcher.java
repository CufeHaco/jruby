/**
 * NaiveMatcher - Simple brute-force pattern matching
 *
 * This is the baseline implementation, useful for:
 * - Very short patterns (2-4 bytes)
 * - Baseline for benchmarking
 * - Fallback when other algorithms aren't applicable
 */
package org.jruby.util;

import org.jcodings.Encoding;

import java.util.ArrayList;
import java.util.List;

public class NaiveMatcher implements ByteMatcher {

    private final byte[] pattern;

    public NaiveMatcher(byte[] pattern) {
        if (pattern == null || pattern.length == 0) {
            throw new IllegalArgumentException("Pattern cannot be null or empty");
        }
        this.pattern = pattern.clone(); // Defensive copy
    }

    @Override
    public int search(byte[] source, int offset, int length, Encoding enc) {
        if (pattern.length > length) {
            return -1; // Pattern longer than search space
        }

        int end = offset + length - pattern.length + 1;

        for (int i = offset; i < end; i++) {
            if (matchAt(source, i, enc)) {
                return i;
            }
        }

        return -1;
    }

    @Override
    public int[] searchAll(byte[] source, int offset, int length, Encoding enc) {
        List<Integer> matches = new ArrayList<>();

        if (pattern.length > length) {
            return new int[0];
        }

        int end = offset + length - pattern.length + 1;

        for (int i = offset; i < end; i++) {
            if (matchAt(source, i, enc)) {
                matches.add(i);
                // Skip past this match to avoid overlapping matches
                // For overlapping matches, remove this line
                // i += pattern.length - 1;
            }
        }

        // Convert to primitive int array
        int[] result = new int[matches.size()];
        for (int i = 0; i < matches.size(); i++) {
            result[i] = matches.get(i);
        }
        return result;
    }

    @Override
    public boolean matchAt(byte[] source, int pos, Encoding enc) {
        // Check bounds
        if (pos < 0 || pos + pattern.length > source.length) {
            return false;
        }

        // Compare byte by byte
        for (int i = 0; i < pattern.length; i++) {
            if (source[pos + i] != pattern[i]) {
                return false;
            }
        }

        return true;
    }

    @Override
    public byte[] getPattern() {
        return pattern.clone();
    }

    @Override
    public int patternLength() {
        return pattern.length;
    }
}
