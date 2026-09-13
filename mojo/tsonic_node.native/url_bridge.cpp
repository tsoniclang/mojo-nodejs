#include "vendor/ada/ada.h"
#include "url/scalar_params.h"
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>

namespace {
struct UrlState {
  std::optional<ada::url_aggregator> url;
  ada::url_search_params params;
  std::string scratch;
};

std::string_view input(const char* bytes, size_t length) {
  if (length > ada::get_max_input_length()) throw std::length_error("URL input is too large");
  return std::string_view(bytes, length);
}

template <typename Operation> int guarded(Operation operation) noexcept {
  try {
    operation();
    return 0;
  } catch (const std::bad_alloc&) {
    errno = ENOMEM;
  } catch (const std::length_error&) {
    errno = EOVERFLOW;
  } catch (const std::exception&) {
    errno = EINVAL;
  }
  return -1;
}

template <typename Operation> int mutate(UrlState& state, Operation operation) noexcept {
  return guarded([&] {
    if (!state.url) {
      operation(state.params);
      return;
    }
    auto params = state.params;
    operation(params);
    const auto query = params.to_string();
    input(query.data(), query.size());
    auto url = *state.url;
    url.set_search(query);
    state.url = std::move(url);
    state.params = std::move(params);
  });
}
}

extern "C" void* tsonic_node_url_new(const char* bytes, size_t length,
    const char* base_bytes, size_t base_length, int has_base) noexcept {
  std::unique_ptr<UrlState> state;
  const auto status = guarded([&] {
    std::optional<ada::url_aggregator> base;
    if (has_base) {
      auto parsed = ada::parse<ada::url_aggregator>(input(base_bytes, base_length));
      if (!parsed) throw std::invalid_argument("Invalid base URL");
      base = std::move(*parsed);
    }
    auto parsed = ada::parse<ada::url_aggregator>(input(bytes, length), base ? &*base : nullptr);
    if (!parsed) throw std::invalid_argument("Invalid URL");
    state = std::make_unique<UrlState>();
    state->url = std::move(*parsed);
    state->params = tsonic_node_url::scalar_params(state->url->get_search());
  });
  return status == 0 ? state.release() : nullptr;
}

extern "C" void* tsonic_node_url_params_new(const char* bytes, size_t length) noexcept {
  std::unique_ptr<UrlState> state;
  const auto status = guarded([&] {
    state = std::make_unique<UrlState>();
    state->params = tsonic_node_url::scalar_params(input(bytes, length));
  });
  return status == 0 ? state.release() : nullptr;
}

extern "C" void tsonic_node_url_free(void* handle) noexcept {
  delete static_cast<UrlState*>(handle);
}

extern "C" char* tsonic_node_url_domain(const char* bytes, size_t length,
    int unicode, size_t* output_length) noexcept {
  char* output = nullptr;
  *output_length = 0;
  const auto status = guarded([&] {
    if (length > ada::idna::max_domain_input_bytes) throw std::length_error("Domain input is too large");
    const auto domain = input(bytes, length);
    std::string result;
    if (!domain.empty()) {
      auto parsed = ada::parse<ada::url>("ws://x");
      if (!parsed) throw std::logic_error("Unable to initialize special-scheme host parser");
      if (parsed->set_hostname(domain)) {
        result = unicode ? ada::idna::to_unicode(parsed->get_hostname()) : std::string(parsed->get_hostname());
      }
    }
    output = static_cast<char*>(std::malloc(result.size() + 1));
    if (!output) throw std::bad_alloc();
    std::memcpy(output, result.data(), result.size());
    output[result.size()] = '\0';
    *output_length = result.size();
  });
  return status == 0 ? output : nullptr;
}

extern "C" void tsonic_node_url_domain_free(char* output) noexcept {
  std::free(output);
}

extern "C" int tsonic_node_url_can_parse(const char* bytes, size_t length,
    const char* base_bytes, size_t base_length, int has_base) noexcept {
  bool valid = false;
  const auto status = guarded([&] {
    const auto text = input(bytes, length);
    const auto base = input(base_bytes, base_length);
    valid = ada::can_parse(text, has_base ? &base : nullptr);
  });
  return status == 0 ? static_cast<int>(valid) : -1;
}

extern "C" const char* tsonic_node_url_get(void* handle, int field, size_t* length) noexcept {
  auto& state = *static_cast<UrlState*>(handle);
  std::string_view result;
  const auto status = guarded([&] {
    switch (field) {
      case 0: result = state.url->get_href(); break;
      case 1: result = state.url->get_protocol(); break;
      case 2: result = state.url->get_username(); break;
      case 3: result = state.url->get_password(); break;
      case 4: result = state.url->get_host(); break;
      case 5: result = state.url->get_hostname(); break;
      case 6: result = state.url->get_port(); break;
      case 7: result = state.url->get_pathname(); break;
      case 8: result = state.url->get_search(); break;
      case 9: result = state.url->get_hash(); break;
      case 10: state.scratch = state.url->get_origin(); result = state.scratch; break;
      case 11: state.scratch = state.params.to_string(); result = state.scratch; break;
      default: throw std::invalid_argument("Unknown URL field");
    }
  });
  if (status != 0) { *length = 0; return nullptr; }
  *length = result.size();
  return result.empty() ? "" : result.data();
}

extern "C" int tsonic_node_url_set(void* handle, int field,
    const char* bytes, size_t length) noexcept {
  auto& state = *static_cast<UrlState*>(handle);
  return guarded([&] {
    const auto text = input(bytes, length);
    auto url = *state.url;
    switch (field) {
      case 0:
        if (!url.set_href(text)) throw std::invalid_argument("Invalid URL");
        break;
      case 1: url.set_protocol(text); break;
      case 2: url.set_username(text); break;
      case 3: url.set_password(text); break;
      case 4: url.set_host(text); break;
      case 5: url.set_hostname(text); break;
      case 6: url.set_port(text); break;
      case 7: url.set_pathname(text); break;
      case 8: url.set_search(text); break;
      case 9: url.set_hash(text); break;
      default: throw std::invalid_argument("Unknown URL field");
    }
    if (field == 0 || field == 8) {
      auto params = tsonic_node_url::scalar_params(url.get_search());
      state.params = std::move(params);
    }
    state.url = std::move(url);
  });
}

extern "C" size_t tsonic_node_url_params_size(void* handle) noexcept {
  return static_cast<UrlState*>(handle)->params.size();
}

extern "C" const char* tsonic_node_url_params_at(void* handle,
    size_t index, int key, size_t* length) noexcept {
  auto& params = static_cast<UrlState*>(handle)->params;
  if (index >= params.size()) { *length = 0; return nullptr; }
  const auto& pair = *(params.begin() + index);
  const auto& text = key ? pair.first : pair.second;
  *length = text.size();
  return text.data();
}

extern "C" int tsonic_node_url_params_has(void* handle, const char* key,
    size_t key_length, const char* value, size_t value_length, int match_value) noexcept {
  auto& params = static_cast<UrlState*>(handle)->params;
  return match_value ? params.has(std::string_view(key, key_length), std::string_view(value, value_length))
    : params.has(std::string_view(key, key_length));
}

extern "C" int tsonic_node_url_params_mutate(void* handle, int operation,
    const char* key, size_t key_length, const char* value, size_t value_length) noexcept {
  auto& state = *static_cast<UrlState*>(handle);
  return mutate(state, [&](ada::url_search_params& params) {
    const auto name = input(key, key_length);
    const auto text = input(value, value_length);
    switch (operation) {
      case 0: params.append(name, text); break;
      case 1: params.set(name, text); break;
      case 2: params.remove(name); break;
      case 3: params.remove(name, text); break;
      case 4: params.sort(); break;
      default: throw std::invalid_argument("Unknown URLSearchParams operation");
    }
  });
}
