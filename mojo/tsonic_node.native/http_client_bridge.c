#define _POSIX_C_SOURCE 200809L
#include <curl/curl.h>
#include <uv.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

typedef struct {
  CURL* easy;
  struct curl_slist* headers;
  unsigned char* body;
  size_t size;
  size_t capacity;
  size_t limit;
  CURLcode result;
  long status;
  int active;
  int complete;
  char error[CURL_ERROR_SIZE];
} HttpRequest;

static uv_once_t initialized = UV_ONCE_INIT;
static uv_mutex_t lock;
static CURLM* multi;
static int initialization_error;

static void initialize(void) {
  initialization_error = uv_mutex_init(&lock);
  if (initialization_error != 0) return;
  if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK) {
    initialization_error = -1;
    return;
  }
  multi = curl_multi_init();
  if (!multi) initialization_error = -1;
}

static size_t receive_body(char* data, size_t size, size_t count, void* context) {
  HttpRequest* request = context;
  if (size != 0 && count > SIZE_MAX / size) return CURL_WRITEFUNC_ERROR;
  size_t length = size * count;
  if (length > request->limit - request->size) {
    static const char message[] = "HTTP response exceeds the runtime byte budget";
    memcpy(request->error, message, sizeof(message));
    return CURL_WRITEFUNC_ERROR;
  }
  size_t required = request->size + length;
  if (required > request->capacity) {
    size_t capacity = request->capacity ? request->capacity : 4096;
    while (capacity < required) capacity = capacity > request->limit / 2 ? request->limit : capacity * 2;
    unsigned char* body = realloc(request->body, capacity);
    if (!body) return CURL_WRITEFUNC_ERROR;
    request->body = body;
    request->capacity = capacity;
  }
  if (length) memcpy(request->body + request->size, data, length);
  request->size = required;
  return length;
}

static int selected(HttpRequest* request, CURLcode code) {
  if (code == CURLE_OK) return 1;
  request->result = code;
  return 0;
}

void* tsonic_node_http_new(const char* url, size_t limit) {
  uv_once(&initialized, initialize);
  if (initialization_error) return NULL;
  HttpRequest* request = calloc(1, sizeof(HttpRequest));
  if (!request) return NULL;
  request->limit = limit;
  request->easy = curl_easy_init();
  if (!request->easy) { free(request); return NULL; }
  selected(request, curl_easy_setopt(request->easy, CURLOPT_URL, url));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_PROTOCOLS_STR, "http,https"));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_PROXY, ""));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_FOLLOWLOCATION, 0L));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_NOSIGNAL, 1L));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_WRITEFUNCTION, receive_body));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_WRITEDATA, request));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_ERRORBUFFER, request->error));
  selected(request, curl_easy_setopt(request->easy, CURLOPT_PRIVATE, request));
  const char* certificate_file = getenv("SSL_CERT_FILE");
  const char* certificate_directory = getenv("SSL_CERT_DIR");
  if (certificate_file && *certificate_file) selected(request, curl_easy_setopt(request->easy, CURLOPT_CAINFO, certificate_file));
  if (certificate_directory && *certificate_directory) selected(request, curl_easy_setopt(request->easy, CURLOPT_CAPATH, certificate_directory));
  return request;
}

int tsonic_node_http_header(void* value, const char* header) {
  HttpRequest* request = value;
  if (request->active || request->complete) return 0;
  struct curl_slist* headers = curl_slist_append(request->headers, header);
  if (!headers) return 0;
  request->headers = headers;
  return 1;
}

int tsonic_node_http_tls(void* value, int verify, int minimum, int maximum,
    const void* ca, size_t ca_length, const void* cert, size_t cert_length,
    const void* key, size_t key_length, const void* pfx, size_t pfx_length,
    const char* password) {
  HttpRequest* request = value;
  if (request->active || request->complete) return 0;
  long versions[] = { CURL_SSLVERSION_DEFAULT, CURL_SSLVERSION_TLSv1,
    CURL_SSLVERSION_TLSv1_1, CURL_SSLVERSION_TLSv1_2, CURL_SSLVERSION_TLSv1_3 };
  long maxima[] = { CURL_SSLVERSION_MAX_DEFAULT, CURL_SSLVERSION_MAX_TLSv1_0,
    CURL_SSLVERSION_MAX_TLSv1_1, CURL_SSLVERSION_MAX_TLSv1_2, CURL_SSLVERSION_MAX_TLSv1_3 };
  if (minimum < 0 || minimum > 4 || maximum < 0 || maximum > 4) return 0;
  if (!selected(request, curl_easy_setopt(request->easy, CURLOPT_SSL_VERIFYPEER, verify ? 1L : 0L)) ||
      !selected(request, curl_easy_setopt(request->easy, CURLOPT_SSL_VERIFYHOST, verify ? 2L : 0L)) ||
      !selected(request, curl_easy_setopt(request->easy, CURLOPT_SSLVERSION, versions[minimum] | maxima[maximum]))) return 0;
  if (ca_length) {
    struct curl_blob blob = { (void*)ca, ca_length, CURL_BLOB_COPY };
    if (!selected(request, curl_easy_setopt(request->easy, CURLOPT_CAINFO_BLOB, &blob))) return 0;
  }
  if (cert_length) {
    struct curl_blob blob = { (void*)cert, cert_length, CURL_BLOB_COPY };
    if (!selected(request, curl_easy_setopt(request->easy, CURLOPT_SSLCERT_BLOB, &blob))) return 0;
  }
  if (key_length) {
    struct curl_blob blob = { (void*)key, key_length, CURL_BLOB_COPY };
    if (!selected(request, curl_easy_setopt(request->easy, CURLOPT_SSLKEY_BLOB, &blob))) return 0;
  }
  if (pfx_length) {
    struct curl_blob blob = { (void*)pfx, pfx_length, CURL_BLOB_COPY };
    if (!selected(request, curl_easy_setopt(request->easy, CURLOPT_SSLCERTTYPE, "P12")) ||
        !selected(request, curl_easy_setopt(request->easy, CURLOPT_SSLCERT_BLOB, &blob))) return 0;
  }
  if (password && !selected(request, curl_easy_setopt(request->easy, CURLOPT_KEYPASSWD, password))) return 0;
  return 1;
}

int tsonic_node_http_start(void* value, const char* method, const void* body,
    size_t length, int body_present, long timeout) {
  HttpRequest* request = value;
  if (request->active || request->complete || request->result != CURLE_OK) return 0;
  const char* implicit[] = { "Accept", "Expect", "Content-Type" };
  for (size_t index = 0; index < sizeof(implicit) / sizeof(implicit[0]); index++) {
    size_t name_length = strlen(implicit[index]);
    int present = 0;
    for (struct curl_slist* header = request->headers; header; header = header->next) {
      if (strlen(header->data) > name_length && strncasecmp(header->data, implicit[index], name_length) == 0 &&
          (header->data[name_length] == ':' || header->data[name_length] == ';')) present = 1;
    }
    if (!present) {
      char suppressed[32];
      memcpy(suppressed, implicit[index], name_length);
      suppressed[name_length] = ':';
      suppressed[name_length + 1] = '\0';
      if (!tsonic_node_http_header(request, suppressed)) return 0;
    }
  }
  if (!selected(request, curl_easy_setopt(request->easy, CURLOPT_HTTPHEADER, request->headers))) return 0;
  if (body_present &&
      (!selected(request, curl_easy_setopt(request->easy, CURLOPT_POSTFIELDSIZE_LARGE, (curl_off_t)length)) ||
       !selected(request, curl_easy_setopt(request->easy, CURLOPT_COPYPOSTFIELDS, length ? body : "")))) return 0;
  if (strcmp(method, "HEAD") == 0 && !selected(request, curl_easy_setopt(request->easy, CURLOPT_NOBODY, 1L))) return 0;
  if (!selected(request, curl_easy_setopt(request->easy, CURLOPT_CUSTOMREQUEST, method)) ||
      !selected(request, curl_easy_setopt(request->easy, CURLOPT_TIMEOUT_MS, timeout))) return 0;
  uv_mutex_lock(&lock);
  CURLMcode result = curl_multi_add_handle(multi, request->easy);
  if (result == CURLM_OK) request->active = 1;
  uv_mutex_unlock(&lock);
  return result == CURLM_OK;
}

int tsonic_node_http_poll(void) {
  uv_once(&initialized, initialize);
  if (initialization_error) return -1;
  uv_mutex_lock(&lock);
  int running = 0;
  CURLMcode result = curl_multi_perform(multi, &running);
  int remaining;
  CURLMsg* message;
  while ((message = curl_multi_info_read(multi, &remaining))) {
    if (message->msg != CURLMSG_DONE) continue;
    HttpRequest* request = NULL;
    CURLcode metadata = curl_easy_getinfo(message->easy_handle, CURLINFO_PRIVATE, &request);
    if (metadata != CURLE_OK || !request) { result = CURLM_INTERNAL_ERROR; break; }
    request->result = message->data.result;
    if (request->result == CURLE_OK) request->result = curl_easy_getinfo(request->easy, CURLINFO_RESPONSE_CODE, &request->status);
    request->complete = 1;
    request->active = 0;
    curl_multi_remove_handle(multi, request->easy);
  }
  uv_mutex_unlock(&lock);
  return result == CURLM_OK ? running : -1;
}

int tsonic_node_http_complete(void* value) {
  uv_mutex_lock(&lock);
  int result = ((HttpRequest*)value)->complete;
  uv_mutex_unlock(&lock);
  return result;
}

const char* tsonic_node_http_error(void* value) {
  HttpRequest* request = value;
  if (request->result == CURLE_OK) return NULL;
  return request->error[0] ? request->error : curl_easy_strerror(request->result);
}

int tsonic_node_http_status(void* value) { return (int)((HttpRequest*)value)->status; }
const void* tsonic_node_http_body(void* value, size_t* length) {
  HttpRequest* request = value;
  *length = request->size;
  return request->body;
}

void tsonic_node_http_free(void* value) {
  HttpRequest* request = value;
  if (!request) return;
  uv_mutex_lock(&lock);
  if (request->active) curl_multi_remove_handle(multi, request->easy);
  curl_easy_cleanup(request->easy);
  uv_mutex_unlock(&lock);
  curl_slist_free_all(request->headers);
  free(request->body);
  free(request);
}
