// The x86_64 slice of Needle.xcframework. Cactus ships libneedle for arm64 only, so on Intel every call fails.
#include "needle.h"

int needle_load(const unsigned char *cact, unsigned long long n) { return -1; }
int needle_models(void) { return 0; }
const char *needle_last_error(void) { return "Whistle is unavailable on Intel Macs"; }
int needle_init(const char *system_prompt, const char *tools_json, const char *tool_index_path) { return -1; }
int needle_complete(const char *input, const float *pcm, int samples, int max_new_tokens, char *out, int out_capacity) { return -1; }
void needle_set_audio(const char *language, const char *keywords, int word_timestamps) {}
void needle_reset(void) {}
int needle_transcribe(const float *pcm, int samples, const char *language, const char *keywords, int word_timestamps, char *out, int out_capacity) { return -1; }
int needle_stream_transcribe_process(const float *pcm, int samples, const char *language, const char *keywords, char *out, int out_capacity) { return -1; }
int needle_stream_transcribe_stop(char *out, int out_capacity) { return -1; }
int needle_embed(const char *input, const float *pcm, int samples, float *out, int out_capacity) { return -1; }
