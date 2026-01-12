/**
 * SingleByteMatcher - Optimized matcher for single byte patterns
 *
 * This is the most common case (searching for a single character)
 * and can be heavily optimized. Future versions can use SIMD.
 */
package org.jruby.util;

import org.jcodings.Encoding;

import java.util.ArrayList;
import java.util.List;

public class SingleByteMatcher implements ByteMatcher {

    private final byte target;

    public SingleByteMatcher(byte target) {
        this.target = target;
    }

    @Override
    public int search(byte[] source, int offset, int length, Encoding enc) {
        // Simple linear search - can be SIMD accelerated later
        int end = offset + length;
        for (int i = offset; i < end; i++) {
            if (source[i] == target) {
                return i;
            }
        }
        return -1;
    }

    @Override
    public int[] searchAll(byte[] source, int offset, int length, Encoding enc) {
        List<Integer> matches = new ArrayList<>();
        int end = offset + length;

        for (int i = offset; i < end; i++) {
            if (source[i] == target) {
                matches.add(i);
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
        return pos >= 0 && pos < source.length && source[pos] == target;
    }

    @Override
    public byte[] getPattern() {
        return new byte[]{target};
    }

    @Override
    public int patternLength() {
        return 1;
    }

    /**
     * Optimized version using long-wise comparison (future SIMD candidate)
     * Processes 8 bytes at a time on 64-bit systems
     */
    public int searchOptimized(byte[] source, int offset, int length) {
        int end = offset + length;
        int i = offset;

        // Align to 8-byte boundary
        while (i < end && (i & 7) != 0) {
            if (source[i] == target) return i;
            i++;
        }

        // Process 8 bytes at a time
        long targetPattern = broadcastByte(target);
        while (i + 8 <= end) {
            long chunk = getLong(source, i);
            if (hasMatchingByte(chunk, targetPattern)) {
                // Found a match, find exact position
                for (int j = i; j < i + 8; j++) {
                    if (source[j] == target) return j;
                }
            }
            i += 8;
        }

        // Handle remaining bytes
        while (i < end) {
            if (source[i] == target) return i;
            i++;
        }

        return -1;
    }

    /**
     * Broadcast byte to all positions in a long
     * e.g., 0x42 -> 0x4242424242424242
     */
    private long broadcastByte(byte b) {
        long l = b & 0xFFL;
        l |= l << 8;
        l |= l << 16;
        l |= l << 32;
        return l;
    }

    /**
     * Read 8 bytes as a long (platform-dependent endianness)
     */
    private long getLong(byte[] source, int offset) {
        return ((long) source[offset] & 0xFF) |
               ((long) source[offset + 1] & 0xFF) << 8 |
               ((long) source[offset + 2] & 0xFF) << 16 |
               ((long) source[offset + 3] & 0xFF) << 24 |
               ((long) source[offset + 4] & 0xFF) << 32 |
               ((long) source[offset + 5] & 0xFF) << 40 |
               ((long) source[offset + 6] & 0xFF) << 48 |
               ((long) source[offset + 7] & 0xFF) << 56;
    }

    /**
     * Check if any byte in chunk matches target
     * Uses SWAR (SIMD Within A Register) technique
     */
    private boolean hasMatchingByte(long chunk, long pattern) {
        // XOR with pattern - matching bytes become 0x00
        long xor = chunk ^ pattern;

        // SWAR magic: detect any 0x00 byte
        // If a byte is 0x00, subtracting 1 causes a borrow
        long magic = 0x7F7F7F7F7F7F7F7FL;
        return (((xor - 0x0101010101010101L) & ~xor & 0x8080808080808080L) != 0);
    }
}
