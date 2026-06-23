# frozen_string_literal: true

# Boot - Reusable Bootloader with Real Bit Vector Logic (v0.6)
#
# - Thread-local integer bit vectors
# - Explicit bitwise operations (set, clear, test, toggle)
# - Feature flag support
# - Dynamic arrays + hotload + StringIO
# - load_directory with rich extension filtering & conditional handling
# - Advanced version system with auto-detection (directory + file header/shebang)

module Boot
  VERSION = '0.6.0'

  $boot_loaded   ||= []
  $boot_features ||= []
  $boot_versions ||= []

  @bit_registry      = {}
  @next_bit_position = 0
  @registry_mutex    = Mutex.new

  # ============================================================
  # VERSION CONSTANTS
  # ============================================================
  CURRENT_VERSION = '0.5.0'
  MIN_VERSION     = '0.4.0'

  $boot_version_order  ||= []
  $boot_active_version ||= nil

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

    # Backward-compatible simple versioned loader
    def load_versioned(entries)
      entries.map do |e|
        { path: e[:path], loaded: load(e[:path], version: e[:version]) }
      end
    end

    # ============================================================
    # NEW: load_directory with extension filtering & conditional dispatch
    # ============================================================

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
      in /[*?{]/      then ext
      in String       then [ext.start_with?(".") ? ext : ".#{ext}"]
      in nil          then nil
      end
    end

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
      content
    end

    def load_json(path)
      require 'json' unless defined?(JSON)
      data = JSON.parse(File.read(path))
      mark(File.basename(path, '.json'))
      data
    end

    # ============================================================
    # ADVANCED VERSION SYSTEM
    # ============================================================

    def current_version
      CURRENT_VERSION
    end

    def set_current_version(ver)
      $boot_active_version = ver.to_s
    end

    def activate_version(ver)
      $boot_active_version = ver.to_s
      set_bit("version_#{ver}")
    end

    def version_active?(ver)
      $boot_active_version == ver.to_s || bit_set?("version_#{ver}".to_sym)
    end

    # Priority 1: file header (first 5 lines)
    def extract_version_from_file_header(path)
      return nil unless File.exist?(path)

      File.open(path, "r") do |f|
        5.times do
          line = f.gets
          break unless line

          return $1 if line =~ /#!.*kestowv.*version[:\s=]+(\d+\.\d+(?:\.\d+)?)/i
          return $1 if line =~ /version[:\s=]+["']?(\d+\.\d+(?:\.\d+)?)["']?/i
        end
      end
      nil
    rescue
      nil
    end

    # Priority 2: parent directory name
    def extract_version_from_path(path)
      path.split("/").reverse_each do |part|
        return $1 if part =~ /kest[oó]w?v[\._-]?(\d+\.\d+(?:\.\d+)?)/i
        return $1 if part =~ /\A(\d+\.\d+(?:\.\d+)?)\z/
      end
      nil
    end

    def load_versioned_smart(entries, current: CURRENT_VERSION)
      set_current_version(current)

      ordered = generate_version_order(entries, current: current)

      ordered.each do |entry|
        result = load(entry[:path], version: entry[:version])

        $boot_version_order << {
          path:             entry[:path],
          detected_version: entry[:version],
          loaded:           result,
          active:           entry[:version] == current
        }
      end

      $boot_version_order
    end

    def generate_version_order(entries, current: CURRENT_VERSION)
      current_prefix = current.split(".").first(2).join(".")

      local_first = []
      current_ver = []
      older       = []

      entries.each do |entry|
        path           = entry[:path]
        header_version = extract_version_from_file_header(path)
        dir_version    = extract_version_from_path(path)
        final_version  = header_version || entry[:version] || dir_version || current

        resolved = entry.merge(version: final_version)

        case path
        when /\/(local|bin)\//
          local_first << resolved
        else
          next if Gem::Version.new(final_version) < Gem::Version.new(MIN_VERSION)

          if final_version == current || final_version.start_with?(current_prefix)
            current_ver << resolved
          else
            older << resolved
          end
        end
      end

      local_first + current_ver + older
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
