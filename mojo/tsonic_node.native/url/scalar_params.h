#ifndef TSONIC_NODE_URL_SCALAR_PARAMS_H
#define TSONIC_NODE_URL_SCALAR_PARAMS_H

#include "../vendor/ada/ada.h"
#include <unicode/utf8.h>
#include <optional>
#include <string>
#include <string_view>

namespace tsonic_node_url {

inline std::optional<std::string> replace_invalid_utf8(std::string_view text) {
  std::optional<std::string> result;
  size_t offset = 0;
  size_t copied = 0;
  while (offset < text.size()) {
    const auto start = offset;
    UChar32 code_point;
    U8_NEXT(text.data(), offset, text.size(), code_point);
    if (code_point < 0) {
      if (!result) result.emplace();
      result->append(text.substr(copied, start - copied));
      result->append("\xef\xbf\xbd");
      copied = offset;
    }
  }
  if (result) result->append(text.substr(copied));
  return result;
}

inline ada::url_search_params scalar_params(std::string_view query) {
  ada::url_search_params parsed(query);
  std::optional<ada::url_search_params> normalized;
  for (auto entry = parsed.begin(); entry != parsed.end(); ++entry) {
    auto key = replace_invalid_utf8(entry->first);
    auto value = replace_invalid_utf8(entry->second);
    if (!normalized && (key || value)) {
      normalized.emplace();
      for (auto previous = parsed.begin(); previous != entry; ++previous) {
        normalized->append(previous->first, previous->second);
      }
    }
    if (normalized) {
      normalized->append(key ? std::string_view(*key) : entry->first,
                         value ? std::string_view(*value) : entry->second);
    }
  }
  return normalized ? std::move(*normalized) : std::move(parsed);
}

}

#endif
