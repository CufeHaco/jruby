/**
 * BoyerMooreMatcher - Boyer-Moore string search algorithm
 *
 * Efficient for longer patterns (> 4 bytes).
 * Key advantages:
 * - O(n/m) average case (better than O(n) naive)
 * - Skips characters using bad character rule
 * - Scans right-to-left for early mismatch detection
 *
 * Performance: 2-10x faster than naive for typical text patterns
 */
package org.jruby.util;

import org.jcodings.Encoding;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class BoyerMooreMatcher implements ByteMatcher {

    private final byte[] pattern;
    private final int[] badCharTable;

    public BoyerMooreMatcher(byte[] pattern) {
        if (pattern == null || pattern.length == 0) {
            throw new IllegalArgumentException("Pattern cannot be null or empty");
        }
        this.pattern = pattern.clone();
        this.badCharTable = buildBadCharTable(pattern);
    }

    /**
     * Build bad character shift table
     * For each byte value (0-255), stores how far we can skip ahead
     */
    private static int[] buildBadCharTable(byte[] pattern) {
        int[] table = new int[256];
        int patternLength = pattern.length;

        // Initialize all shifts to pattern length
        Arrays.fill(table, patternLength);

        // Fill in actual shifts for characters that appear in pattern
        for (int i = 0; i < patternLength - 1; i++) {
            int ch = pattern[i] & 0xFF; // Treat as unsigned
            table[ch] = patternLength - 1 - i;
        }

        return table;
    }

    @Override
    public int search(byte[] source, int offset, int length, Encoding enc) {
        int patternLength = pattern.length;

        if (patternLength > length) {
            return -1;
        }

        int end = offset + length;
        int i = offset;

        while (i <= end - patternLength) {
            // Scan from right to left
            int j = patternLength - 1;

            while (j >= 0 && source[i + j] == pattern[j]) {
                j--;
            }

            if (j < 0) {
                // Match found
                return i;
            }

            // Mismatch - skip ahead using bad character rule
            int badChar = source[i + j] & 0xFF;
            int shift = badCharTable[badChar];

            // Ensure we always move forward
            i += Math.max(1, shift);
        }

        return -1;
    }

    @Override
    public int[] searchAll(byte[] source, int offset, int length, Encoding enc) {
        List<Integer> matches = new ArrayList<>();
        int patternLength = pattern.length;

        if (patternLength > length) {
            return new int[0];
        }

        int end = offset + length;
        int i = offset;

        while (i <= end - patternLength) {
            // Scan from right to left
            int j = patternLength - 1;

            while (j >= 0 && source[i + j] == pattern[j]) {
                j--;
            }

            if (j < 0) {
                // Match found
                matches.add(i);
                i += patternLength; // Move past this match
            } else {
                // Mismatch - skip ahead using bad character rule
                int badChar = source[i + j] & 0xFF;
                int shift = badCharTable[badChar];
                i += Math.max(1, shift);
            }
        }

        // Convert to primitive int array
        int[] result = new int[matches.size()];
        for (int k = 0; k < matches.size(); k++) {
            result[k] = matches.get(k);
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

    /**
     * Get bad character table (for testing/debugging)
     */
    public int[] getBadCharTable() {
        return badCharTable.clone();
    }
}
