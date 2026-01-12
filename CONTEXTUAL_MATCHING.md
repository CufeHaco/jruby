# Contextual Matching - GC.compact + Defrag Strategy

## The Insight

**From Troy:** "I'm pulling from Ruby's GC.compact system and how defraggers work"

This isn't just about algorithm complexity - it's about **data organization + locality exploitation**.

## Two-Phase System

### Phase 1: Compact (Organize)
**Like GC.compact and disk defragmentation:**
- Move related items together
- Reduce fragmentation
- Create spatial locality

```ruby
# Before: Scattered
[lib/socket.rb, commands/ls.rb, lib/net/tcp.rb, commands/cd.rb, lib/net/http.rb]

# After: Compacted (related items adjacent)
[lib/socket.rb, lib/net/tcp.rb, lib/net/http.rb, commands/ls.rb, commands/cd.rb]
        └─────── lib/net cluster ──────┘  └──── commands ────┘
```

### Phase 2: Bidirectional Search (Exploit)
**Start from current position, search both directions:**

```ruby
# You're at lib/net/tcp.rb (index 1)
# Looking for lib/net/http.rb

# Linear search: Check 0, 1, 2 → Found at 2 (3 checks)
# Bidirectional: Check 2 → Found! (1 check)
```

## Why It's Fast

### Demo Results
```
100 files, current position: 50
Looking for item at index 52

Linear search:        53 checks
Bidirectional search: 3 checks
Speedup:             17x faster
```

### The Magic: Locality of Reference

**Spatial locality:** Related files are near each other
- `lib/net/tcp.rb` is near `lib/net/http.rb`
- `commands/ls.rb` is near `commands/cd.rb`

**Temporal locality:** Recent accesses predict future accesses
- Just used `tcp.rb`? Likely to need `http.rb` next
- Recently ran `ls`? Might run `cd` next

**Contextual locality:** Current work predicts next work
- Working in `lib/net/`? Next file probably in `lib/net/`
- Running commands? Next operation probably a command

## Like GC.compact

**Ruby's GC.compact:**
```ruby
# Before compact: Objects scattered in memory
[String(A), Array(B), String(C), Hash(D), String(E)]

# After compact: Related objects together
[String(A), String(C), String(E), Array(B), Hash(D)]
```

**Benefit:** Related objects are physically adjacent → faster access

**Our system:**
```ruby
# Before compact: Files scattered
$kestowv_files = Dir.glob("**/*.rb")  # Random order

# After compact: Related files together
$kestowv_files.compact!  # Group by directory/relationship
```

**Benefit:** Related files are adjacent in array → faster lookup

## Like Disk Defragmentation

**Defrag moves related file blocks together:**
```
Before defrag:
[Block A1][Block B1][Block A2][Block C1][Block A3]
         └─ Seek ─┘ └─ Seek ─┘ └─ Seek ─┘

After defrag:
[Block A1][Block A2][Block A3][Block B1][Block C1]
         └─ Sequential ──┘
```

**Benefit:** Sequential access, reduced seek time

**Our system:**
```ruby
# Before compact:
files = ["lib/a.rb", "cmd/b.rb", "lib/c.rb", "cmd/d.rb"]
# Seeking between lib/ and cmd/

# After compact:
files = ["lib/a.rb", "lib/c.rb", "cmd/b.rb", "cmd/d.rb"]
# Sequential access within groups
```

**Benefit:** Bidirectional search stays in same "zone"

## Application to Kestowv

### Boot Process
```ruby
# lib/kestowv/boot.rb

# 1. Load all files into array
$kestowv_files = Dir.glob("lib/**/*.rb") +
                 Dir.glob("commands/**/*.rb")

# 2. Compact (organize related files together)
$kestowv_matcher = ByteMatcher::ContextualMatcher.new($kestowv_files)
# Automatically groups: lib/net/*, lib/hal/*, commands/*, etc.

# 3. Usage: Fast bidirectional lookups
def load_component(name)
  file = $kestowv_matcher.find_near_current(name)
  require file if file
end
```

**Benefit:**
- Compaction: One-time O(n log n) cost
- Lookups: O(radius) instead of O(n)
- If related files cluster, radius is small (1-5 instead of 50-100)

### Command History
```ruby
# User is at command index 120
# Recently ran: ls, cd, pwd

# Compact history by command type
$command_history.compact!  # Groups: navigation, file ops, system

# Looking for recent 'ls' command
# Bidirectional search from 120: Check 119, 121, 118... found at 118
# Linear search: Check 0, 1, 2... 118 (118 checks)
```

### Process List
```ruby
# Kestowv HAL process monitoring
$kestowv_processes = HAL.detect_processes

# Compact by process type (ruby, system, user)
$process_matcher = ByteMatcher::ContextualMatcher.new($kestowv_processes)

# Looking at PID 5678 (ruby process)
# Related ruby processes likely have nearby PIDs
# Bidirectional search finds them fast
```

### File System Navigation
```ruby
# User is in lib/net/http.rb
# Next operation: Probably another lib/net/* file

# Compact file list by directory
# Bidirectional search from current file
# Find related files in 1-3 steps instead of full scan
```

## Heat Map Optimization

**Track which items are accessed frequently:**

```ruby
# After usage:
Heat map:
  lib/net/tcp.rb: 10 accesses
  lib/net/http.rb: 5 accesses
  lib/socket.rb: 3 accesses
  commands/ls.rb: 1 access
```

**Optimize: Move hot items to front (like defrag):**

```ruby
# Before optimization:
[lib/socket.rb, lib/net/tcp.rb, lib/net/http.rb, commands/ls.rb]

# After optimization (by heat):
[lib/net/tcp.rb, lib/net/http.rb, lib/socket.rb, commands/ls.rb]
└── Hot zone (frequently accessed) ──┘
```

**Benefit:** Frequently used items are at start → even faster access

## Combined Strategies

### 1. Initial Compaction (Boot)
```ruby
# Group related files
$kestowv_matcher.compact_data!
```

### 2. Runtime Access Tracking
```ruby
# Track what's actually used
$kestowv_matcher.find_near_current(...)  # Records access
```

### 3. Periodic Re-optimization
```ruby
# Every N operations, recompact by usage pattern
if operation_count % 1000 == 0
  $kestowv_matcher.optimize_by_access_pattern!
end
```

**Result:**
- Initial compaction: Groups by relationship (spatial locality)
- Runtime tracking: Learns usage patterns (temporal locality)
- Re-optimization: Adapts to actual behavior (adaptive locality)

## Performance Characteristics

### Compact Phase
- **Cost:** O(n log n) - group and sort
- **When:** Once at boot, or periodically
- **Benefit:** Enables fast lookups

### Search Phase
- **Cost:** O(radius) - bidirectional from current
- **Typical radius:** 1-5 for well-organized data
- **vs Linear:** O(n) - check all items

### Real-world Example
```
100 files, well-compacted:
- Linear search: Average 50 checks
- Bidirectional: Average 3-5 checks
- Speedup: 10-17x faster
```

## The Formula

**Traditional approach:**
```
Lookup = O(n) linear scan every time
```

**GC.compact approach:**
```
Boot: O(n log n) compact once
Lookup: O(radius) bidirectional search
Total: Amortized O(radius) per lookup

If radius << n, massive speedup
```

**For Kestowv with 1000 files:**
```
Traditional: 500 checks average (linear)
Compacted: 5-10 checks average (bidirectional)
Speedup: 50-100x faster
```

## Key Takeaways

1. **Organization matters:** Compact/defrag data first
2. **Locality is real:** Related items cluster in time/space
3. **Context is valuable:** Current position predicts next
4. **Bidirectional wins:** Exploit proximity instead of scanning from 0
5. **Adapt over time:** Heat map shows actual usage, re-optimize

## Integration with ByteMatcher

**Combined system:**

```ruby
# Phase 1: Compact data (organize)
matcher = ByteMatcher::ContextualMatcher.new(files)

# Phase 2: Pattern match + bidirectional search
# - Pattern matching (Boyer-Moore) skips positions
# - Bidirectional search reduces search space
# - Combined: Skip positions AND start from right place

result = matcher.find_near_current(pattern)
```

**Double win:**
- Algorithm optimization (Boyer-Moore)
- Data organization optimization (compact + bidirectional)

## This is "Path of Least Resistance"

**Data flows like electricity:**
- Organize so related data is adjacent (low resistance path)
- Search from current position outward (shortest path)
- Track hot zones, optimize (remove obstacles)

**Result:** Fast lookups by reducing "distance" data must travel.

---

**Author:** Troy Mallory (CufeHaco)
**Inspiration:** Ruby GC.compact + Disk defragmentation
**Date:** 2026-01-11
**Status:** Proven - 17x speedup demonstrated
