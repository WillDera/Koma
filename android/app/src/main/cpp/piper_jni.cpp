#include <android/log.h>
#include <jni.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#include <piper.h>

#define LOG_TAG "KomaPiper"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

std::mutex g_mutex;
std::unordered_map<jlong, piper_synthesizer *> g_synths;
jlong g_next_handle = 1;

void write_wav_header(std::vector<uint8_t> &out, uint32_t pcm_bytes,
                      int sample_rate) {
  const uint16_t channels = 1;
  const uint16_t bits = 16;
  const uint32_t byte_rate = static_cast<uint32_t>(sample_rate * channels *
                                                     bits / 8);
  const uint16_t block_align = channels * bits / 8;
  const uint32_t file_size = 36 + pcm_bytes;

  out.resize(44 + pcm_bytes);
  auto *p = out.data();
  std::memcpy(p, "RIFF", 4);
  p += 4;
  std::memcpy(p, &file_size, 4);
  p += 4;
  std::memcpy(p, "WAVE", 4);
  p += 4;
  std::memcpy(p, "fmt ", 4);
  p += 4;
  const uint32_t fmt_size = 16;
  std::memcpy(p, &fmt_size, 4);
  p += 4;
  const uint16_t audio_format = 1;
  std::memcpy(p, &audio_format, 2);
  p += 2;
  std::memcpy(p, &channels, 2);
  p += 2;
  std::memcpy(p, &sample_rate, 4);
  p += 4;
  std::memcpy(p, &byte_rate, 4);
  p += 4;
  std::memcpy(p, &block_align, 2);
  p += 2;
  std::memcpy(p, &bits, 2);
  p += 2;
  std::memcpy(p, "data", 4);
  p += 4;
  std::memcpy(p, &pcm_bytes, 4);
}

std::vector<int16_t> floats_to_pcm16(const float *samples, size_t count) {
  std::vector<int16_t> pcm(count);
  for (size_t i = 0; i < count; ++i) {
    const float clamped = std::clamp(samples[i], -1.0f, 1.0f);
    pcm[i] = static_cast<int16_t>(clamped * 32767.0f);
  }
  return pcm;
}

jbyteArray make_wav_jbyte_array(JNIEnv *env, const std::vector<int16_t> &pcm,
                                int sample_rate) {
  const uint32_t pcm_bytes =
      static_cast<uint32_t>(pcm.size() * sizeof(int16_t));
  std::vector<uint8_t> wav;
  write_wav_header(wav, pcm_bytes, sample_rate);
  std::memcpy(wav.data() + 44, pcm.data(), pcm_bytes);

  jbyteArray result = env->NewByteArray(static_cast<jsize>(wav.size()));
  if (result == nullptr) {
    return nullptr;
  }
  env->SetByteArrayRegion(result, 0, static_cast<jsize>(wav.size()),
                          reinterpret_cast<const jbyte *>(wav.data()));
  return result;
}

} // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_koma_koma_piper_PiperNative_nativeVersion(JNIEnv *env, jclass) {
  const char *version = piper_version();
  return env->NewStringUTF(version != nullptr ? version : "unknown");
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_koma_koma_piper_PiperNative_nativeCreate(JNIEnv *env, jclass,
                                                  jstring model_path,
                                                  jstring config_path,
                                                  jstring espeak_path) {
  const char *model = env->GetStringUTFChars(model_path, nullptr);
  const char *config = env->GetStringUTFChars(config_path, nullptr);
  const char *espeak = env->GetStringUTFChars(espeak_path, nullptr);

  piper_synthesizer *synth =
      piper_create(model, config, espeak);

  env->ReleaseStringUTFChars(model_path, model);
  env->ReleaseStringUTFChars(config_path, config);
  env->ReleaseStringUTFChars(espeak_path, espeak);

  if (synth == nullptr) {
    LOGE("piper_create failed");
    return 0;
  }

  std::lock_guard<std::mutex> lock(g_mutex);
  const jlong handle = g_next_handle++;
  g_synths[handle] = synth;
  return handle;
}

extern "C" JNIEXPORT void JNICALL
Java_com_koma_koma_piper_PiperNative_nativeFree(JNIEnv *, jclass, jlong handle) {
  std::lock_guard<std::mutex> lock(g_mutex);
  auto it = g_synths.find(handle);
  if (it == g_synths.end()) {
    return;
  }
  piper_free(it->second);
  g_synths.erase(it);
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_koma_koma_piper_PiperNative_nativeSynthesize(
    JNIEnv *env, jclass, jlong handle, jstring text, jfloat length_scale,
    jfloat noise_scale, jfloat noise_w_scale, jint speaker_id) {
  piper_synthesizer *synth = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_synths.find(handle);
    if (it == g_synths.end()) {
      LOGE("invalid synthesizer handle");
      return nullptr;
    }
    synth = it->second;
  }

  const char *utf = env->GetStringUTFChars(text, nullptr);
  if (utf == nullptr) {
    return nullptr;
  }

  piper_synthesize_options options =
      piper_default_synthesize_options(synth);
  options.length_scale = length_scale;
  options.noise_scale = noise_scale;
  options.noise_w_scale = noise_w_scale;
  options.speaker_id = speaker_id;

  const int start_rc =
      piper_synthesize_start(synth, utf, &options);
  env->ReleaseStringUTFChars(text, utf);

  if (start_rc != PIPER_OK) {
    LOGE("piper_synthesize_start failed: %d", start_rc);
    return nullptr;
  }

  std::vector<int16_t> pcm;
  int sample_rate = 22050;
  piper_audio_chunk chunk{};
  int rc = PIPER_OK;
  while (rc == PIPER_OK) {
    rc = piper_synthesize_next(synth, &chunk);
    if (rc == PIPER_DONE) {
      break;
    }
    if (rc != PIPER_OK) {
      LOGE("piper_synthesize_next failed: %d", rc);
      return nullptr;
    }
    if (chunk.samples != nullptr && chunk.num_samples > 0) {
      sample_rate = chunk.sample_rate;
      const auto part = floats_to_pcm16(chunk.samples, chunk.num_samples);
      pcm.insert(pcm.end(), part.begin(), part.end());
    }
    if (chunk.is_last) {
      break;
    }
  }

  if (pcm.empty()) {
    LOGE("synthesis produced no audio");
    return nullptr;
  }

  return make_wav_jbyte_array(env, pcm, sample_rate);
}
