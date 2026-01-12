#!/bin/bash
#
# Test UniversalByteMatcher - Compile and verify
#

set -e

echo "=== UniversalByteMatcher Test Suite ==="
echo

# Get jcodings JAR
JCODINGS_JAR=$(find ~/.m2/repository/org/jruby/jcodings -name "jcodings-*.jar" 2>/dev/null | head -1)

if [ -z "$JCODINGS_JAR" ]; then
    echo "Error: jcodings JAR not found"
    echo "Run: cd jruby-pr && ./mvnw dependency:resolve"
    exit 1
fi

echo "Found jcodings: $JCODINGS_JAR"
echo

# Compile Java code
echo "Step 1: Compiling Java implementation..."
mkdir -p /tmp/universal-matcher-test

javac -d /tmp/universal-matcher-test \
      -cp "$JCODINGS_JAR" \
      core/src/main/java/org/jruby/util/UniversalByteMatcher.java

if [ $? -eq 0 ]; then
    echo "✓ Java compilation successful"
else
    echo "✗ Java compilation failed"
    exit 1
fi

echo

# Test Java directly
echo "Step 2: Testing Java implementation..."
cat > /tmp/universal-matcher-test/TestJava.java << 'EOF'
import org.jruby.util.UniversalByteMatcher;

public class TestJava {
    public static void main(String[] args) {
        // Test 1: Simple string search
        byte[] haystack = "Hello World".getBytes();
        byte[] needle = "World".getBytes();

        UniversalByteMatcher matcher = new UniversalByteMatcher(
            needle,
            UniversalByteMatcher.MatchMode.CONTAINS
        );

        int pos = matcher.findFirst(haystack);

        System.out.println("Test 1: Finding 'World' in 'Hello World'");
        System.out.println("  Position: " + pos);
        System.out.println("  Expected: 6");
        System.out.println("  Result: " + (pos == 6 ? "✓ PASS" : "✗ FAIL"));
        System.out.println();

        // Test 2: Find all occurrences
        byte[] text = "Mississippi".getBytes();
        byte[] pattern = "ss".getBytes();

        UniversalByteMatcher matcher2 = new UniversalByteMatcher(
            pattern,
            UniversalByteMatcher.MatchMode.CONTAINS
        );

        int[] positions = matcher2.findAll(text);

        System.out.println("Test 2: Finding all 'ss' in 'Mississippi'");
        System.out.print("  Positions: ");
        for (int p : positions) {
            System.out.print(p + " ");
        }
        System.out.println();
        System.out.println("  Expected: 2 5");
        System.out.println("  Result: " + (positions.length == 2 ? "✓ PASS" : "✗ FAIL"));
        System.out.println();

        // Test 3: Match at position
        System.out.println("Test 3: Match at specific position");
        boolean match = matcher.matchAt(haystack, 6);
        System.out.println("  Match at position 6: " + match);
        System.out.println("  Expected: true");
        System.out.println("  Result: " + (match ? "✓ PASS" : "✗ FAIL"));
        System.out.println();

        System.out.println("=== Java Tests Complete ===");
    }
}
EOF

javac -d /tmp/universal-matcher-test \
      -cp "/tmp/universal-matcher-test:$JCODINGS_JAR" \
      /tmp/universal-matcher-test/TestJava.java

java -cp "/tmp/universal-matcher-test:$JCODINGS_JAR" TestJava

echo

# Test Ruby wrapper (if JRuby available)
echo "Step 3: Testing Ruby wrapper..."

if command -v jruby &> /dev/null; then
    export CLASSPATH="/tmp/universal-matcher-test:$JCODINGS_JAR"

    jruby -I lib/ruby/stdlib << 'RUBY'
require 'universal_byte_matcher'

puts "Test 1: Basic byte matching"
data = "Hello World".bytes
pattern = "World".bytes
matcher = UniversalByteMatcher.new(data, mode: :contains)
result = matcher.find_first(pattern)
puts "  Position: #{result}"
puts "  Expected: 6"
puts "  Result: #{result == 6 ? '✓ PASS' : '✗ FAIL'}"
puts

puts "Test 2: Find all matches"
data = "Mississippi".bytes
pattern = "ss".bytes
matcher = UniversalByteMatcher.new(data, mode: :contains)
results = matcher.find_matching(pattern)
puts "  Positions: #{results.inspect}"
puts "  Expected: [2, 5]"
puts "  Result: #{results == [2, 5] ? '✓ PASS' : '✗ FAIL'}"
puts

puts "Test 3: String matcher wrapper"
require 'byte_matcher/string_matcher'
text = "The quick brown fox"
matcher = ByteMatcher::StringMatcher.new(text)
pos = matcher.index("fox")
puts "  Finding 'fox' in '#{text}'"
puts "  Position: #{pos}"
puts "  Expected: 16"
puts "  Result: #{pos == 16 ? '✓ PASS' : '✗ FAIL'}"
puts

puts "=== Ruby Tests Complete ==="
RUBY
else
    echo "JRuby not found, skipping Ruby tests"
fi

echo
echo "=== All Tests Complete ==="
echo
echo "Next steps:"
echo "  1. Run: ./UniversalByteMatcherDemo.rb"
echo "  2. Review benchmarks"
echo "  3. Integrate with JRuby core"
