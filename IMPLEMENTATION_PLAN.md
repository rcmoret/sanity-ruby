# Implementation Plan: Perspective Support for Queries

Based on PR #39 review comments from @dvmonroe, this plan outlines the implementation of perspective support for Sanity queries.

## Overview

The PR requested adding perspective option support to queries. The reviewer requested several improvements:

1. Create a Perspective object with validation for the 4 allowed values
2. Handle the `useCdn`/`previewDrafts` conflict (when `previewDrafts` is used, `useCdn` must be false)
3. Add `perspective` to the Configuration object (similar to `use_cdn`)
4. Add/update unit tests

## Implementation Steps

### Step 1: Create Perspective Object/Class

**File:** `lib/sanity/perspective.rb` (new file)

**Purpose:** Create a value object that validates and encapsulates perspective values.

**Implementation:**
- Define the 4 allowed perspective values (based on Sanity docs):
  - `"published"` (default)
  - `"previewDrafts"`
  - `"raw"`
  - `"publishedIds"`
- Create a class that:
  - Validates input against allowed values
  - Provides a default value (`"published"`)
  - Can be initialized with a string or symbol
  - Converts to string for API usage
  - Raises `ArgumentError` for invalid values

**Example structure:**
```ruby
module Sanity
  class Perspective
    VALID_VALUES = %w[published previewDrafts raw publishedIds].freeze
    DEFAULT = "published".freeze

    attr_reader :value

    def initialize(value = nil)
      @value = (value || DEFAULT).to_s
      validate!
    end

    def to_s
      value
    end

    def preview_drafts?
      value == "previewDrafts"
    end

    private

    def validate!
      unless VALID_VALUES.include?(value)
        raise ArgumentError, "perspective must be one of #{VALID_VALUES.join(', ')}"
      end
    end
  end
end
```

### Step 2: Add Perspective to Configuration

**File:** `lib/sanity/configuration.rb`

**Changes:**
1. Add `perspective` attribute accessor
2. Initialize with default perspective (using `Sanity::Perspective::DEFAULT`)
3. Add validation in setter to ensure valid perspective values
4. Add ENV variable support: `SANITY_PERSPECTIVE`
5. Update `to_h` method to include perspective

**Implementation details:**
- Use `Sanity::Perspective` class for validation
- Default to `"published"` if not set
- Store as `Sanity::Perspective` instance internally
- Convert to string when needed for API calls

**Additional consideration:**
- Add validation that when `perspective` is `"previewDrafts"`, `use_cdn` must be `false`
- This can be done in the setter or in a validation method

### Step 3: Handle useCdn/previewDrafts Conflict

**Files:** 
- `lib/sanity/configuration.rb` (validation logic)
- Potentially `lib/sanity/http/query.rb` or `lib/sanity/http/where.rb` (runtime check)

**Implementation:**
- In `Configuration#perspective=`, check if setting to `"previewDrafts"` and `use_cdn` is `true`
- If conflict detected:
  - Option A: Automatically set `use_cdn = false` with a warning
  - Option B: Raise an error explaining the conflict
  - Option C: Raise an error and require explicit `use_cdn = false` first
- In `Configuration#use_cdn=`, check if `perspective` is `"previewDrafts"` and raise error if trying to set `use_cdn = true`

**Recommended approach:** Option C (raise error) - more explicit and prevents silent behavior changes

### Step 4: Integrate Perspective into Query Classes

**Files:**
- `lib/sanity/http/query.rb` (base module)
- `lib/sanity/http/where.rb` (where queries)
- `lib/sanity/http/find.rb` (find queries - if applicable)

**Changes:**
1. In `Sanity::Http::Query` module:
   - Delegate `perspective` from config (similar to how `use_cdn` is handled via `api_subdomain`)
   - Or access via `Sanity.config.perspective`

2. In `Sanity::Http::Where`:
   - Extract `perspective` from args in `initialize`
   - Use config default if not provided
   - Add `perspective` to query parameters in `query_and_variables` method
   - For GET requests: add as query parameter `perspective=value`
   - For POST requests: add to request body under `params` or top-level

3. In `Sanity::Http::Find`:
   - Similar integration if perspective applies to find queries
   - Check Sanity docs to confirm if perspective works with find endpoint

**Query parameter format:**
- According to Sanity docs, perspective is a query parameter
- For GET: `?perspective=previewDrafts&query=...`
- For POST: Include in request body JSON

### Step 5: Update Tests

**Files to create/update:**
- `test/sanity/perspective_test.rb` (new)
- `test/sanity/configuration_test.rb` (update)
- `test/sanity/http/where_test.rb` (update)
- `test/sanity/http/find_test.rb` (update if applicable)

**Test coverage needed:**

1. **Perspective class tests:**
   - Valid values are accepted
   - Invalid values raise ArgumentError
   - Default value is "published"
   - String and symbol inputs work
   - `preview_drafts?` helper method works

2. **Configuration tests:**
   - Perspective can be set via accessor
   - Perspective defaults to "published"
   - Perspective can be set via ENV variable
   - Invalid perspective raises error
   - `use_cdn` conflict with `previewDrafts` raises error
   - Setting `previewDrafts` when `use_cdn=true` raises error
   - Setting `use_cdn=true` when `perspective=previewDrafts` raises error
   - Thread safety with perspective (if applicable)

3. **Where query tests:**
   - Perspective is included in GET query string
   - Perspective is included in POST request body
   - Perspective defaults to config value if not provided
   - Perspective can be overridden per query
   - Perspective works with other query parameters

4. **Find query tests:**
   - Perspective is included if applicable
   - Perspective defaults to config value

### Step 6: Update Documentation

**Files:**
- `README.md`

**Updates needed:**
- Add perspective to configuration examples
- Document the 4 valid perspective values
- Document the `use_cdn`/`previewDrafts` conflict
- Add examples of using perspective in queries
- Update ENV variable documentation

## Implementation Order

1. **Step 1** - Create Perspective class (foundation)
2. **Step 2** - Add to Configuration (core integration)
3. **Step 3** - Add conflict validation (safety)
4. **Step 4** - Integrate into queries (functionality)
5. **Step 5** - Add tests (verification)
6. **Step 6** - Update docs (documentation)

## Additional Considerations

### Sanity API Details to Verify

Before implementing, verify:
- Exact perspective parameter name (is it `perspective` or `perspective`?)
- Whether perspective applies to both `where` and `find` queries
- Exact format for GET vs POST requests
- Whether perspective is a query parameter or header

### Backwards Compatibility

- Default perspective should be `"published"` to maintain current behavior
- Existing queries without perspective should continue to work
- Configuration should be optional (defaults provided)

### Error Messages

Provide clear, helpful error messages:
- When invalid perspective is provided
- When `use_cdn`/`previewDrafts` conflict occurs
- Include valid values in error messages

## Testing Checklist

- [ ] Perspective class validates correctly
- [ ] Configuration accepts and stores perspective
- [ ] Configuration validates use_cdn/previewDrafts conflict
- [ ] Where queries include perspective parameter
- [ ] Find queries include perspective parameter (if applicable)
- [ ] Default perspective is "published"
- [ ] Perspective can be overridden per query
- [ ] Thread safety maintained with perspective
- [ ] ENV variable support works
- [ ] Error messages are clear and helpful

## References

- [Sanity Perspectives Documentation](https://www.sanity.io/docs/perspectives)
- PR #39: https://github.com/dvmonroe/sanity-ruby/pull/39
- Current codebase structure and patterns

