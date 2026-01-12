# JRuby Core Integration - Contextual Matching

## Goal

Integrate bidirectional search + data compaction into JRuby's RubyArray.java to enable 10-50x faster array lookups when exploiting locality of reference.

## Inspiration

**From Troy:** "I'm pulling from Ruby's GC.compact system and how defraggers work"

This combines:
- **GC.compact:** Organize related objects together
- **Disk defrag:** Reduce seek time by grouping related data
- **Bidirectional search:** Search up and down from current position, not from 0

## Key Insight

**Traditional array.index():**
```java
// Always starts at 0, scans entire array
for (int i = 0; i < realLength; i++) {
    if (match) return i;
}
// Average: O(n/2) checks
```

**Contextual array.index():**
```java
// Start from last access, search both directions
radius = 0
while (radius < maxRadius) {
    check position - radius  // backward
    check position + radius  // forward
    radius++
}
// Average with good locality: O(5-10) checks
// Speedup: 10-50x faster
```

## Implementation Strategy

### Phase 1: Add Context Tracking to RubyArray.java

**Add fields:**
```java
// Context tracking for bidirectional search
private int lastAccessIndex = 0;         // Last index accessed
private boolean enableBidirectional = false;  // Feature flag
private int[] accessHeatMap = null;      // Optional: track hot zones
```

**These fields track:**
- Where we last accessed the array
- Whether to use bidirectional search (can be enabled globally or per-array)
- Heat map for optimization (optional, added later)

### Phase 2: Implement Bidirectional Search

**Add method:**
```java
private int searchBidirectional(ThreadContext context, IRubyObject obj, int startPos) {
    int maxRadius = realLength;

    for (int radius = 0; radius < maxRadius; radius++) {
        // Check backward
        int backIdx = startPos - radius;
        if (backIdx >= 0 && backIdx < realLength) {
            if (equalInternal(context, eltOk(backIdx), obj)) {
                lastAccessIndex = backIdx;
                return backIdx;
            }
        }

        // Check forward (skip radius 0 to avoid duplicate)
        if (radius > 0) {
            int forwardIdx = startPos + radius;
            if (forwardIdx >= 0 && forwardIdx < realLength) {
                if (equalInternal(context, eltOk(forwardIdx), obj)) {
                    lastAccessIndex = forwardIdx;
                    return forwardIdx;
                }
            }
        }
    }

    return -1;  // Not found
}
```

### Phase 3: Modify index() Method

**Update existing index():**
```java
public IRubyObject index(ThreadContext context, IRubyObject obj) {
    int foundIndex;

    // Use bidirectional search if enabled and we have context
    if (enableBidirectional && lastAccessIndex >= 0 && lastAccessIndex < realLength) {
        foundIndex = searchBidirectional(context, obj, lastAccessIndex);
    } else {
        // Fall back to linear search from 0
        foundIndex = -1;
        for (int i = 0; i < realLength; i++) {
            if (equalInternal(context, eltOk(i), obj)) {
                foundIndex = i;
                lastAccessIndex = i;  // Update context
                break;
            }
        }
    }

    return foundIndex == -1 ? context.nil : asFixnum(context, foundIndex);
}
```

### Phase 4: Add Ruby Methods for Control

**Add methods to enable/disable:**
```java
@JRubyMethod(name = "enable_bidirectional_search!")
public IRubyObject enableBidirectionalSearch(ThreadContext context) {
    this.enableBidirectional = true;
    return context.tru;
}

@JRubyMethod(name = "compact!")
public IRubyObject compact_bang(ThreadContext context) {
    // Group related items together
    // For now, just enable bidirectional search
    // Future: implement actual data compaction
    this.enableBidirectional = true;
    return this;
}

@JRubyMethod(name = "bidirectional_enabled?")
public IRubyObject bidirectionalEnabled(ThreadContext context) {
    return enableBidirectional ? context.tru : context.fals;
}
```

## Usage Example (Ruby Side)

```ruby
# Kestowv boot optimization
$kestowv_files = Dir.glob("lib/**/*.rb")

# Enable bidirectional search
$kestowv_files.enable_bidirectional_search!

# Or use compact! (which enables it)
$kestowv_files.compact!

# Now lookups are fast
file = $kestowv_files.index("lib/net/tcp.rb")
# Next lookup starts from that position
file2 = $kestowv_files.index("lib/net/http.rb")
# Found in ~2 checks instead of 500
```

## Benefits

### For Kestowv Boot
```ruby
$kestowv_files = Dir.glob("lib/**/*.rb")  # 1000 files
$kestowv_files.compact!

# Traditional: Average 500 checks per lookup
# Bidirectional: Average 5-10 checks per lookup
# Speedup: 50-100x faster
```

### For File Loading
```ruby
$LOAD_PATH.compact!  # Enable bidirectional

require 'socket'     # Loads socket.rb, updates context
require 'net/tcp'    # Starts search from socket.rb position
require 'net/http'   # Starts from net/tcp position
# Each subsequent require is faster due to locality
```

### For Process Lists
```ruby
processes = HAL.detect_processes  # 200 processes
processes.compact!

current = processes.index { |p| p.pid == 1234 }
next_ruby = processes.index { |p| p.name == "ruby" }
# Related processes cluster together
```

## Performance Characteristics

### Best Case (High Locality)
```
Array size: 1000
Current position: 500
Target position: 505
Traditional: 506 checks
Bidirectional: 6 checks
Speedup: 84x faster
```

### Worst Case (Low Locality)
```
Array size: 1000
Current position: 500
Target position: 0
Traditional: 1 check (at beginning)
Bidirectional: 501 checks (worst case)
Speedup: 0.5x (2x slower)
```

### Average Case (Good Locality)
```
Array size: 1000
Related items within 50 positions
Traditional: 500 checks average
Bidirectional: 10-25 checks average
Speedup: 20-50x faster
```

## Feature Flag Strategy

**Start conservative:**
1. Add fields, disabled by default
2. Add methods, require explicit enable
3. Collect data on effectiveness
4. Gradually enable by default if beneficial

**Global enable option:**
```bash
jruby -J-Djruby.array.bidirectional=true script.rb
```

**Per-array enable:**
```ruby
arr.enable_bidirectional_search!
# or
arr.compact!  # Also enables bidirectional
```

## Future Enhancements

### Heat Map Tracking
```java
private void recordAccess(int index) {
    if (accessHeatMap == null) {
        accessHeatMap = new int[realLength];
    }
    accessHeatMap[index]++;
}
```

### Actual Data Compaction
```java
public IRubyObject compact_bang(ThreadContext context, Block block) {
    // Group items using block's grouping logic
    // Rearrange array so related items are adjacent
    // Like GC.compact for memory
}
```

### Adaptive Switching
```java
// Automatically enable bidirectional if we detect locality
private void checkLocality() {
    if (recentAccessesNearby()) {
        enableBidirectional = true;
    }
}
```

## Testing Strategy

### Unit Tests
```java
// Test bidirectional search correctness
public void testBidirectionalSearch() {
    RubyArray arr = RubyArray.newArray(runtime, 100);
    arr.enableBidirectionalSearch(context);
    // Populate with test data
    // Verify correct results
}
```

### Performance Tests
```ruby
# Benchmark traditional vs bidirectional
Benchmark.bmbm do |x|
  x.report("traditional") { 1000.times { arr.index(target) } }

  arr.compact!
  x.report("bidirectional") { 1000.times { arr.index(target) } }
end
```

### Integration Tests (Kestowv)
```ruby
# Test with actual Kestowv boot
require 'benchmark'

time_without = Benchmark.realtime { load_kestowv_without_compact }
time_with = Benchmark.realtime { load_kestowv_with_compact }

puts "Speedup: #{time_without / time_with}x"
```

## Rollout Plan

### Step 1: Implementation (Week 1)
- Add fields to RubyArray.java
- Implement searchBidirectional()
- Add control methods
- Unit tests

### Step 2: Testing (Week 2)
- Performance benchmarks
- Kestowv integration tests
- Verify correctness

### Step 3: Feedback (Week 3)
- Share with Charles
- Get community feedback
- Iterate on design

### Step 4: Refinement (Week 4)
- Add heat map if beneficial
- Optimize based on feedback
- Documentation

### Step 5: Merge (Week 5)
- PR to JRuby master
- Default disabled, opt-in
- Monitor performance

## MRI C Version (Future)

After JRuby stabilizes, create C version for MRI:

```c
// array.c modifications
typedef struct RArray {
    // ... existing fields ...
    long last_access_index;
    int bidirectional_enabled;
} RArray;

static long rb_ary_search_bidirectional(VALUE ary, VALUE val, long start) {
    // C implementation of bidirectional search
}
```

Submit to ruby-core for Matz's review.

## Success Criteria

**For this experiment:**
- ✓ Correct results (all tests pass)
- ✓ Measurable speedup (10-50x in good locality cases)
- ✓ No regression (worst case ≤ 2x slower)
- ✓ Charles approves design

**For production:**
- Community feedback positive
- No bugs in 3 months of testing
- Kestowv boot speed improved
- Considered for default enable

---

**Status:** Ready to implement
**Next:** Modify RubyArray.java with Phase 1-4
**Author:** Troy Mallory (CufeHaco) + Claude
**Date:** 2026-01-11
