# frozen_string_literal: true

# Boot - Reusable Bootloader with Real Bit Vector Logic (v0.6)
#
# - Thread-local integer bit vectors
# - Explicit bitwise operations (set, clear, test, toggle)
# - Feature flag support
# - Dynamic arrays + hotload + StringIO
# - load_directory with rich extension filtering & conditional handling

module Boot
  VERSION = '0.6.0'

  $boot_loaded   ||= []
  $boot_features ||= []
  $boot_versions ||= []

  @bit_registry      = {}
  @next_bit_position = 0
  @registry_mutex    = Mutex.new

  class << self
    # ============================================================
    # REGISTRATION
    # ============================================================

    def register(name)
      key = name.to_sym
      @registry_mutex.synchronize do
        return @bit_registry[key] if @bit_registry.key?(key)
        pos = @next_bit_position
        @bit_registry[key] = pos
        @next_bit_position += 1
        pos
      end
    end

    def bit_position(name)
      @bit_registry[name.to_sym]
    end

    # ============================================================
    # THREAD-LOCAL BIT VECTOR
    # ============================================================

    def current_vector
      Thread.current[:boot_bit_vector] ||= 0
    end

    # ============================================================
    # EXPLICIT BITWISE OPERATIONS
    # ============================================================

    def set_bit(name)
      pos = register(name)
      Thread.current[:boot_bit_vector] = current_vector | (1 << pos)
      mark_array(name)
    end

    def clear_bit(name)
      pos = bit_position(name)
      return false unless pos
      Thread.current[:boot_bit_vector] = current_vector & ~(1 << pos)
      invalidate_array(name)
      true
    end

    def bit_set?(name)
      pos = bit_position(name)
      return false unless pos
      (current_vector & (1 << pos)) != 0
    end

    def toggle_bit(name)
      if bit_set?(name)
        clear_bit(name)
      else
        set_bit(name)
      end
    end

    # Raw bitwise operations (by bit position)
    def set_bit_raw(pos)
      Thread.current[:boot_bit_vector] = current_vector | (1 << pos)
    end

    def clear_bit_raw(pos)
      Thread.current[:boot_bit_vector] = current_vector & ~(1 << pos)
    end

    def test_bit_raw(pos)
      (current_vector & (1 << pos)) != 0
    end

    # ============================================================
    # FEATURE FLAG HELPERS
    # ============================================================

    def enabled_features
      @bit_registry.keys.select { |k| bit_set?(k) }
    end

    def loaded?(name)
      bit_set?(name)
    end

    def mark(name)
      set_bit(name)
    end

    def invalidate(name)
      clear_bit(name)
    end

    # ============================================================
    # DYNAMIC ARRAYS (kept in sync)
    # ============================================================

    def mark_array(name)
      str = name.to_s
      $boot_loaded   << str unless $boot_loaded.include?(str)
      $boot_features << str unless $boot_features.include?(str)
    end

    def invalidate_array(name)
      str = name.to_s
      $boot_loaded.reject!   { |e| e == str }
      $boot_features.reject! { |e| e == str }
    end

    # ============================================================
    # LOADING METHODS
    # ============================================================

    def load_files(paths)
      paths.map { |p| [p, load(p)] }
    end

    def load(path, version: nil)
      puts "  [Boot] load: #{path}"
      begin
        require path
        mark(File.basename(path, '.rb'))
        $boot_versions << { file: path, version: version } if version
        true
      rescue => e
        warn "[Boot] FAILED: #{path} - #{e.message}"
        false
      end
    end

    def load_stringio(stringio, name:)
      return false if loaded?(name)
      content = stringio.read
      eval(content, TOPLEVEL_BINDING, name.to_s, 1)
      mark(name)
      true
    rescue => e
      warn "[Boot] StringIO load failed for #{name}: #{e.message}"
      false
    end

    def hotload(path)
      name = File.basename(path, '.rb').to_sym
      puts "  [Boot] HOTLOAD: #{path}"
      invalidate(name)
      load(path)
    end

    def load_versioned(entries)
      entries.map do |e|
        { path: e[:path], loaded: load(e[:path], version: e[:version]) }
      end
    end

    # ============================================================
    # NEW: load_directory with extension filtering & conditional dispatch
    # ============================================================

    # Main entry point (approved API)
    def load_directory(dir,
                        recursive:  false,
                        extensions: nil,
                        pattern:    nil,
                        filter:     nil,
                        on_load:    nil,
                        on_skip:    nil,
                        &block)

      filter ||= block

      files = collect_files(dir,
        recursive:  recursive,
        pattern:    pattern,
        extensions: normalize_extensions(extensions)
      )

      files.each do |path|
        if filter && !filter.call(path)
          on_skip&.call(path)
          next
        end

        dispatch(path)
        on_load&.call(path)
      end
    end

    # Helper to collect files (simple implementation)
    def collect_files(dir, recursive: false, pattern: nil, extensions: nil)
      glob = if recursive
               File.join(dir, "**/*")
             else
               File.join(dir, "*")
             end

      files = Dir.glob(glob).select { |f| File.file?(f) }

      if extensions
        files.select! do |f|
          ext = File.extname(f)
          extensions.any? { |e| ext == e }
        end
      end

      if pattern
        files.select! { |f| File.fnmatch(pattern, f) || File.fnmatch(pattern, File.basename(f)) }
      end

      files
    end

    def normalize_extensions(ext)
      case ext
      in Array        then ext.map { |e| e.start_with?(".") ? e : ".#{e}" }
      in /[*?{]/      then ext          # treat as glob pattern directly
      in String       then [ext.start_with?(".") ? ext : ".#{ext}"]
      in nil          then nil
      end
    end

    # Central dispatch — routes based on extension / type
    def dispatch(path)
      ext = File.extname(path).downcase
      case ext
      when ".rb", ".so"
        load(path)
      when ".txt", ".md", ".conf"
        load_text(path)
      when ".json"
        load_json(path)
      else
        mark("unknown_#{ext}")
      end
    end

    def load_text(path)
      content = File.read(path)
      mark(File.basename(path))
      # Future: parse or register as config/doc
      content
    end

    def load_json(path)
      require 'json' unless defined?(JSON)
      data = JSON.parse(File.read(path))
      mark(File.basename(path, '.json'))
      data
    end

    # ============================================================
    # INTROSPECTION
    # ============================================================

    def to_a
      $boot_loaded
    end

    def features
      $boot_features
    end

    def bit_stats
      {
        registered_features: @bit_registry.size,
        bits_set_in_current_thread: current_vector.to_s(2).count('1')
      }
    end
  end
end
