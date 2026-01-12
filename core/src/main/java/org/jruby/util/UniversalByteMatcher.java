/**
 * UniversalByteMatcher - Bare metal byte matching for JRuby
 *
 * Core philosophy: Data flows like electricity - path of least resistance.
 * Bypass JVM overhead, work directly with byte arrays.
 *
 * This universal matcher works on ANY byte data:
 * - File paths
 * - Strings
 * - Process names
 * - Device paths
 * - Network data
 * - Any byte sequence
 *
 * TRUE Rubian pattern: Same logic scales across all domains.
 */
package org.jruby.util;

import org.jcodings.Encoding;

import java.util.ArrayList;
import java.util.List;

public class UniversalByteMatcher {

    private final byte[] pattern;
    private final MatchMode mode;
    private final boolean useFlagBits;  // PLACEHOLDER: For future 7-bit + flag implementation

    /**
     * Match modes
     */
    public enum MatchMode {
        EXACT,      // Byte-for-byte exact match
        FUZZY,      // Case-insensitive or approximate (future)
        CONTAINS,   // Pattern appears anywhere in data
        STARTS_WITH,
        ENDS_WITH
    }

    /**
     * Create matcher with pattern
     *
     * @param pattern the pattern to match
     * @param mode match mode
     */
    public UniversalByteMatcher(byte[] pattern, MatchMode mode) {
        this(pattern, mode, false);
    }

    /**
     * Create matcher with flag bit support
     *
     * @param pattern the pattern to match
     * @param mode match mode
     * @param useFlagBits whether to interpret bit 7 as metadata flag
     */
    public UniversalByteMatcher(byte[] pattern, MatchMode mode, boolean useFlagBits) {
        if (pattern == null || pattern.length == 0) {
            throw new IllegalArgumentException("Pattern cannot be null or empty");
        }
        this.pattern = pattern.clone();
        this.mode = mode;
        this.useFlagBits = useFlagBits;
    }

    /**
     * Find first match in data
     *
     * @param data the data to search
     * @return index of first match, or -1 if not found
     */
    public int findFirst(byte[] data) {
        if (data == null || data.length == 0) return -1;

        switch (mode) {
            case EXACT:
                return findExact(data, 0, data.length);
            case CONTAINS:
                return findContains(data, 0, data.length);
            case STARTS_WITH:
                return startsWithPattern(data, 0, data.length) ? 0 : -1;
            case ENDS_WITH:
                return endsWithPattern(data, 0, data.length) ? (data.length - pattern.length) : -1;
            case FUZZY:
                return findFuzzy(data, 0, data.length);
            default:
                return -1;
        }
    }

    /**
     * Find all matches in data
     * TRUE Rubian pattern: Returns array of indices
     *
     * @param data the data to search
     * @return array of match indices
     */
    public int[] findAll(byte[] data) {
        if (data == null || data.length == 0) return new int[0];

        List<Integer> matches = new ArrayList<>();
        int pos = 0;

        while (pos < data.length) {
            int match = findContains(data, pos, data.length - pos);
            if (match < 0) break;

            matches.add(pos + match);
            pos += match + pattern.length;  // Move past this match
        }

        // Convert to primitive array
        int[] result = new int[matches.size()];
        for (int i = 0; i < matches.size(); i++) {
            result[i] = matches.get(i);
        }
        return result;
    }

    /**
     * Check if data matches at specific position
     *
     * @param data the data to check
     * @param pos position to check
     * @return true if pattern matches at pos
     */
    public boolean matchAt(byte[] data, int pos) {
        if (pos < 0 || pos + pattern.length > data.length) {
            return false;
        }

        if (useFlagBits) {
            // PLACEHOLDER: Future implementation with flag bit logic
            // For now, extract data bits only
            for (int i = 0; i < pattern.length; i++) {
                byte dataBits = (byte) (data[pos + i] & 0x7F);
                byte patternBits = (byte) (pattern[i] & 0x7F);
                if (dataBits != patternBits) return false;
            }
            return true;
        } else {
            // Standard byte comparison
            for (int i = 0; i < pattern.length; i++) {
                if (data[pos + i] != pattern[i]) return false;
            }
            return true;
        }
    }

    // ============ Private Implementation Methods ============

    private int findExact(byte[] data, int offset, int length) {
        if (pattern.length != length) return -1;
        return matchAt(data, offset) ? offset : -1;
    }

    private int findContains(byte[] data, int offset, int length) {
        if (pattern.length > length) return -1;

        // Use optimized algorithm based on pattern length
        if (pattern.length == 1) {
            return findSingleByte(data, offset, length, pattern[0]);
        } else if (pattern.length <= 4) {
            return findNaive(data, offset, length);
        } else {
            return findBoyerMoore(data, offset, length);
        }
    }

    private int findSingleByte(byte[] data, int offset, int length, byte target) {
        // Direct linear scan - simplest case
        int end = offset + length;
        for (int i = offset; i < end; i++) {
            if (useFlagBits) {
                // Compare data bits only
                if ((data[i] & 0x7F) == (target & 0x7F)) return i;
            } else {
                if (data[i] == target) return i;
            }
        }
        return -1;
    }

    private int findNaive(byte[] data, int offset, int length) {
        int end = offset + length - pattern.length + 1;
        for (int i = offset; i < end; i++) {
            if (matchAt(data, i)) return i;
        }
        return -1;
    }

    private int findBoyerMoore(byte[] data, int offset, int length) {
        // Build bad character table
        int[] badChar = buildBadCharTable();

        int end = offset + length;
        int i = offset;

        while (i <= end - pattern.length) {
            // Scan right to left
            int j = pattern.length - 1;

            while (j >= 0 && data[i + j] == pattern[j]) {
                j--;
            }

            if (j < 0) {
                // Match found
                return i;
            }

            // Shift using bad character rule
            int shift = badChar[data[i + j] & 0xFF];
            i += Math.max(1, shift);
        }

        return -1;
    }

    private int[] buildBadCharTable() {
        int[] table = new int[256];
        int patternLength = pattern.length;

        // Initialize all shifts to pattern length
        for (int i = 0; i < 256; i++) {
            table[i] = patternLength;
        }

        // Fill in actual shifts for characters in pattern
        for (int i = 0; i < patternLength - 1; i++) {
            table[pattern[i] & 0xFF] = patternLength - 1 - i;
        }

        return table;
    }

    private boolean startsWithPattern(byte[] data, int offset, int length) {
        if (pattern.length > length) return false;
        return matchAt(data, offset);
    }

    private boolean endsWithPattern(byte[] data, int offset, int length) {
        if (pattern.length > length) return false;
        int startPos = offset + length - pattern.length;
        return matchAt(data, startPos);
    }

    private int findFuzzy(byte[] data, int offset, int length) {
        // PLACEHOLDER: Future implementation for case-insensitive, approximate matching
        // For now, fall back to exact matching
        return findContains(data, offset, length);
    }

    /**
     * Get the pattern being matched
     *
     * @return pattern bytes
     */
    public byte[] getPattern() {
        return pattern.clone();
    }

    /**
     * Get pattern length
     *
     * @return pattern length
     */
    public int patternLength() {
        return pattern.length;
    }

    /**
     * Check if using flag bits
     *
     * @return true if flag bit mode enabled
     */
    public boolean usesFlagBits() {
        return useFlagBits;
    }

    // ============ Static Helper Methods ============

    /**
     * Static helper method for ByteList.indexOf integration
     * Drop-in replacement with optimized byte matching
     *
     * @param source source byte array
     * @param sourceOffset offset in source
     * @param sourceCount length of source data
     * @param target target pattern to find
     * @param targetOffset offset in target
     * @param targetCount length of target pattern
     * @param fromIndex start position in source
     * @return index of first match, or -1 if not found
     */
    public static int indexOf(byte[] source, int sourceOffset, int sourceCount,
                             byte[] target, int targetOffset, int targetCount, int fromIndex) {
        if (fromIndex >= sourceCount) return (targetCount == 0 ? sourceCount : -1);
        if (fromIndex < 0) fromIndex = 0;
        if (targetCount == 0) return fromIndex;

        // Extract target pattern (handle offset)
        byte[] pattern;
        if (targetOffset == 0 && targetCount == target.length) {
            pattern = target;
        } else {
            pattern = new byte[targetCount];
            System.arraycopy(target, targetOffset, pattern, 0, targetCount);
        }

        // Create matcher and search
        UniversalByteMatcher matcher = new UniversalByteMatcher(pattern, MatchMode.CONTAINS);
        int searchOffset = sourceOffset + fromIndex;
        int searchLength = sourceCount - fromIndex;

        // Search in the source data
        int pos = matcher.findContains(source, searchOffset, searchLength);

        // Convert absolute position to relative position
        if (pos >= 0) {
            return pos - sourceOffset;
        }

        return -1;
    }
}
