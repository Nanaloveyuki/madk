#include <moonbit.h>

#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <dlfcn.h>
#include <time.h>
#endif

/*
 * This file deliberately declares the small libusb ABI surface it uses
 * instead of including libusb.h. The library is loaded at runtime, so a host
 * without the libusb SDK can still compile madk and receives a truthful
 * runtime diagnostic when it attempts to open USB.
 */
typedef struct madk_libusb_context madk_libusb_context;
typedef struct madk_libusb_device madk_libusb_device;
typedef struct madk_libusb_device_handle madk_libusb_device_handle;

typedef struct {
  uint8_t bLength;
  uint8_t bDescriptorType;
  uint16_t bcdUSB;
  uint8_t bDeviceClass;
  uint8_t bDeviceSubClass;
  uint8_t bDeviceProtocol;
  uint8_t bMaxPacketSize0;
  uint16_t idVendor;
  uint16_t idProduct;
  uint16_t bcdDevice;
  uint8_t iManufacturer;
  uint8_t iProduct;
  uint8_t iSerialNumber;
  uint8_t bNumConfigurations;
} madk_libusb_device_descriptor;

typedef struct madk_libusb_endpoint_descriptor {
  uint8_t bLength;
  uint8_t bDescriptorType;
  uint8_t bEndpointAddress;
  uint8_t bmAttributes;
  uint16_t wMaxPacketSize;
  uint8_t bInterval;
  uint8_t bRefresh;
  uint8_t bSynchAddress;
  const unsigned char *extra;
  int32_t extra_length;
} madk_libusb_endpoint_descriptor;

typedef struct madk_libusb_interface_descriptor {
  uint8_t bLength;
  uint8_t bDescriptorType;
  uint8_t bInterfaceNumber;
  uint8_t bAlternateSetting;
  uint8_t bNumEndpoints;
  uint8_t bInterfaceClass;
  uint8_t bInterfaceSubClass;
  uint8_t bInterfaceProtocol;
  uint8_t iInterface;
  const madk_libusb_endpoint_descriptor *endpoint;
  const unsigned char *extra;
  int32_t extra_length;
} madk_libusb_interface_descriptor;

typedef struct madk_libusb_interface {
  const madk_libusb_interface_descriptor *altsetting;
  int32_t num_altsetting;
} madk_libusb_interface;

typedef struct madk_libusb_config_descriptor {
  uint8_t bLength;
  uint8_t bDescriptorType;
  uint16_t wTotalLength;
  uint8_t bNumInterfaces;
  uint8_t bConfigurationValue;
  uint8_t iConfiguration;
  uint8_t bmAttributes;
  uint8_t MaxPower;
  const madk_libusb_interface *interface;
  const unsigned char *extra;
  int32_t extra_length;
} madk_libusb_config_descriptor;

typedef intptr_t madk_libusb_ssize_t;

typedef int (*madk_libusb_init_fn)(madk_libusb_context **);
typedef void (*madk_libusb_exit_fn)(madk_libusb_context *);
typedef madk_libusb_ssize_t (*madk_libusb_get_device_list_fn)(
    madk_libusb_context *, madk_libusb_device ***);
typedef void (*madk_libusb_free_device_list_fn)(madk_libusb_device **, int);
typedef int (*madk_libusb_get_device_descriptor_fn)(
    madk_libusb_device *, madk_libusb_device_descriptor *);
typedef int (*madk_libusb_open_fn)(
    madk_libusb_device *, madk_libusb_device_handle **);
typedef void (*madk_libusb_close_fn)(madk_libusb_device_handle *);
typedef int (*madk_libusb_get_active_config_descriptor_fn)(
    madk_libusb_device *, madk_libusb_config_descriptor **);
typedef int (*madk_libusb_get_config_descriptor_fn)(
    madk_libusb_device *, uint8_t, madk_libusb_config_descriptor **);
typedef void (*madk_libusb_free_config_descriptor_fn)(
    madk_libusb_config_descriptor *);
typedef int (*madk_libusb_set_auto_detach_kernel_driver_fn)(
    madk_libusb_device_handle *, int);
typedef int (*madk_libusb_claim_interface_fn)(madk_libusb_device_handle *, int);
typedef int (*madk_libusb_release_interface_fn)(
    madk_libusb_device_handle *, int);
typedef int (*madk_libusb_control_transfer_fn)(
    madk_libusb_device_handle *, uint8_t, uint8_t, uint16_t, uint16_t,
    unsigned char *, uint16_t, unsigned int);
typedef int (*madk_libusb_bulk_transfer_fn)(
    madk_libusb_device_handle *, uint8_t, unsigned char *, int, int *,
    unsigned int);

typedef struct {
  void *library;
  madk_libusb_init_fn init;
  madk_libusb_exit_fn exit;
  madk_libusb_get_device_list_fn get_device_list;
  madk_libusb_free_device_list_fn free_device_list;
  madk_libusb_get_device_descriptor_fn get_device_descriptor;
  madk_libusb_open_fn open;
  madk_libusb_close_fn close;
  madk_libusb_get_active_config_descriptor_fn get_active_config_descriptor;
  madk_libusb_get_config_descriptor_fn get_config_descriptor;
  madk_libusb_free_config_descriptor_fn free_config_descriptor;
  madk_libusb_set_auto_detach_kernel_driver_fn set_auto_detach;
  madk_libusb_claim_interface_fn claim_interface;
  madk_libusb_release_interface_fn release_interface;
  madk_libusb_control_transfer_fn control_transfer;
  madk_libusb_bulk_transfer_fn bulk_transfer;
} madk_libusb_api;

enum {
  MADK_STATUS_OK = 0,
  MADK_STATUS_INVALID_ARGUMENT = -1001,
  MADK_STATUS_CLOSED = -1002,
  MADK_STATUS_DISCONNECTED = -1003,
  MADK_STATUS_TIMEOUT = -1004,
  MADK_STATUS_ACCESS = -1005,
  MADK_STATUS_NOT_FOUND = -1006,
  MADK_STATUS_UNSUPPORTED = -1007,
  MADK_STATUS_RUNTIME_SYMBOL = -1008,
  MADK_STATUS_RUNTIME_MISSING = -1009,
  MADK_STATUS_OUT_OF_MEMORY = -1010,
  MADK_STATUS_FAILURE = -1012,
  MADK_STATUS_INVALID_ENDPOINT = -1013,
  MADK_STATUS_INVALID_LENGTH = -1014,
};

enum {
  MADK_LIBUSB_ERROR_IO = -1,
  MADK_LIBUSB_ERROR_INVALID_PARAM = -2,
  MADK_LIBUSB_ERROR_ACCESS = -3,
  MADK_LIBUSB_ERROR_NO_DEVICE = -4,
  MADK_LIBUSB_ERROR_NOT_FOUND = -5,
  MADK_LIBUSB_ERROR_BUSY = -6,
  MADK_LIBUSB_ERROR_TIMEOUT = -7,
  MADK_LIBUSB_ERROR_OVERFLOW = -8,
  MADK_LIBUSB_ERROR_PIPE = -9,
  MADK_LIBUSB_ERROR_INTERRUPTED = -10,
  MADK_LIBUSB_ERROR_NO_MEM = -11,
  MADK_LIBUSB_ERROR_NOT_SUPPORTED = -12,
};

static const int MADK_AOA_VENDOR_ID = 0x18D1;

#if defined(_MSC_VER)
#define MADK_THREAD_LOCAL __declspec(thread)
#else
#define MADK_THREAD_LOCAL _Thread_local
#endif

static MADK_THREAD_LOCAL char madk_runtime_error[512];

typedef struct madk_libusb_handle {
  madk_libusb_api api;
  madk_libusb_context *context;
  madk_libusb_device_handle *device;
  int32_t selected_vendor_id;
  int32_t selected_product_id;
  int32_t accessory_mode;
  int32_t waiting_for_accessory;
  int32_t closed;
  int32_t vendor_id;
  int32_t product_id;
  int32_t bulk_in_endpoint;
  int32_t bulk_out_endpoint;
  int32_t interface_number;
  int32_t claimed;
  char error[512];
} madk_libusb_handle;

static void madk_libusb_close_impl(madk_libusb_handle *handle);

static void madk_set_runtime_error(const char *message) {
  if (message == NULL) message = "unknown libusb runtime error";
  snprintf(madk_runtime_error, sizeof(madk_runtime_error), "%s", message);
}

static void madk_set_error(madk_libusb_handle *handle, const char *message) {
  if (handle == NULL) return;
  if (message == NULL) message = "unknown libusb transport error";
  snprintf(handle->error, sizeof(handle->error), "%s", message);
}

#if defined(_WIN32)
static void *madk_load_library(const char *name) {
  return (void *)LoadLibraryA(name);
}

static void *madk_load_symbol(void *library, const char *name) {
  FARPROC symbol = GetProcAddress((HMODULE)library, name);
  return (void *)(uintptr_t)symbol;
}

static void madk_unload_library(void *library) {
  if (library != NULL) FreeLibrary((HMODULE)library);
}
#else
static void *madk_load_library(const char *name) {
  return dlopen(name, RTLD_NOW | RTLD_LOCAL);
}

static void *madk_load_symbol(void *library, const char *name) {
  return dlsym(library, name);
}

static void madk_unload_library(void *library) {
  if (library != NULL) dlclose(library);
}
#endif

static void madk_clear_api(madk_libusb_api *api) {
  memset(api, 0, sizeof(*api));
}

static int madk_load_api(madk_libusb_api *api) {
  madk_clear_api(api);
#if defined(_WIN32)
  const char *names[] = {"libusb-1.0.dll", "libusb-1.0-0.dll"};
#elif defined(__APPLE__)
  const char *names[] = {"libusb-1.0.0.dylib", "libusb-1.0.dylib", "libusb-1.0.so"};
#else
  const char *names[] = {"libusb-1.0.so.0", "libusb-1.0.so"};
#endif
  const size_t name_count = sizeof(names) / sizeof(names[0]);
  for (size_t i = 0; i < name_count; i++) {
    api->library = madk_load_library(names[i]);
    if (api->library != NULL) break;
  }
  if (api->library == NULL) {
    madk_set_runtime_error(
        "libusb 1.0 runtime not found; install the libusb runtime and put "
        "its shared library on PATH/LD_LIBRARY_PATH");
    return MADK_STATUS_RUNTIME_MISSING;
  }

#define MADK_LOAD_REQUIRED(field, type, symbol)                              \
  do {                                                                        \
    api->field = (type)madk_load_symbol(api->library, symbol);                \
    if (api->field == NULL) {                                                  \
      madk_set_runtime_error("libusb runtime is missing symbol " symbol);     \
      madk_unload_library(api->library);                                       \
      madk_clear_api(api);                                                      \
      return MADK_STATUS_RUNTIME_SYMBOL;                                       \
    }                                                                          \
  } while (0)

  MADK_LOAD_REQUIRED(init, madk_libusb_init_fn, "libusb_init");
  MADK_LOAD_REQUIRED(exit, madk_libusb_exit_fn, "libusb_exit");
  MADK_LOAD_REQUIRED(get_device_list, madk_libusb_get_device_list_fn,
                     "libusb_get_device_list");
  MADK_LOAD_REQUIRED(free_device_list, madk_libusb_free_device_list_fn,
                     "libusb_free_device_list");
  MADK_LOAD_REQUIRED(get_device_descriptor,
                     madk_libusb_get_device_descriptor_fn,
                     "libusb_get_device_descriptor");
  MADK_LOAD_REQUIRED(open, madk_libusb_open_fn, "libusb_open");
  MADK_LOAD_REQUIRED(close, madk_libusb_close_fn, "libusb_close");
  MADK_LOAD_REQUIRED(get_active_config_descriptor,
                     madk_libusb_get_active_config_descriptor_fn,
                     "libusb_get_active_config_descriptor");
  MADK_LOAD_REQUIRED(get_config_descriptor,
                     madk_libusb_get_config_descriptor_fn,
                     "libusb_get_config_descriptor");
  MADK_LOAD_REQUIRED(free_config_descriptor,
                     madk_libusb_free_config_descriptor_fn,
                     "libusb_free_config_descriptor");
  MADK_LOAD_REQUIRED(claim_interface, madk_libusb_claim_interface_fn,
                     "libusb_claim_interface");
  MADK_LOAD_REQUIRED(release_interface, madk_libusb_release_interface_fn,
                     "libusb_release_interface");
  MADK_LOAD_REQUIRED(control_transfer, madk_libusb_control_transfer_fn,
                     "libusb_control_transfer");
  MADK_LOAD_REQUIRED(bulk_transfer, madk_libusb_bulk_transfer_fn,
                     "libusb_bulk_transfer");
#undef MADK_LOAD_REQUIRED

  api->set_auto_detach = (madk_libusb_set_auto_detach_kernel_driver_fn)
      madk_load_symbol(api->library, "libusb_set_auto_detach_kernel_driver");
  madk_set_runtime_error("libusb 1.0 runtime loaded");
  return MADK_STATUS_OK;
}

static moonbit_bytes_t madk_text(const char *text) {
  if (text == NULL) text = "";
  size_t length = strlen(text);
  if (length > INT32_MAX) length = INT32_MAX;
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)length, 0);
  if (result != NULL && length > 0) memcpy(result, text, length);
  return result;
}

static int madk_map_libusb_error(
    madk_libusb_handle *handle, int error, const char *operation) {
  const char *reason = "libusb operation failed";
  int status = MADK_STATUS_FAILURE;
  switch (error) {
    case MADK_LIBUSB_ERROR_TIMEOUT:
      status = MADK_STATUS_TIMEOUT;
      reason = "libusb operation timed out";
      break;
    case MADK_LIBUSB_ERROR_NO_DEVICE:
      status = MADK_STATUS_DISCONNECTED;
      reason = "Android USB device disconnected";
      break;
    case MADK_LIBUSB_ERROR_ACCESS:
      status = MADK_STATUS_ACCESS;
      reason = "libusb access denied; check USB permissions and driver binding";
      break;
    case MADK_LIBUSB_ERROR_NOT_FOUND:
      status = MADK_STATUS_NOT_FOUND;
      reason = "libusb configuration or interface was not found";
      break;
    case MADK_LIBUSB_ERROR_NOT_SUPPORTED:
      status = MADK_STATUS_UNSUPPORTED;
      reason = "libusb operation is not supported by this host";
      break;
    case MADK_LIBUSB_ERROR_BUSY:
      reason = "libusb interface is busy; detach the conflicting driver";
      break;
    case MADK_LIBUSB_ERROR_NO_MEM:
      status = MADK_STATUS_OUT_OF_MEMORY;
      reason = "libusb ran out of memory";
      break;
    case MADK_LIBUSB_ERROR_INVALID_PARAM:
      status = MADK_STATUS_INVALID_ARGUMENT;
      reason = "libusb rejected an invalid parameter";
      break;
    case MADK_LIBUSB_ERROR_PIPE:
      reason = "libusb endpoint stalled";
      break;
    default:
      break;
  }
  if (handle != NULL) {
    snprintf(handle->error, sizeof(handle->error), "%s: libusb error %d",
             operation == NULL ? "USB operation" : operation, error);
    if (status == MADK_STATUS_ACCESS || status == MADK_STATUS_FAILURE) {
      size_t used = strlen(handle->error);
      if (used + 2 < sizeof(handle->error)) {
        snprintf(handle->error + used, sizeof(handle->error) - used,
                 " (%s)", reason);
      }
    }
  }
  return status;
}

static int madk_is_accessory_product(int32_t product_id) {
  return product_id >= 0x2D00 && product_id <= 0x2D05;
}

static int madk_matches(
    madk_libusb_handle *handle, const madk_libusb_device_descriptor *descriptor) {
  if (handle->accessory_mode) {
    return descriptor->idVendor == MADK_AOA_VENDOR_ID &&
           madk_is_accessory_product(descriptor->idProduct);
  }
  return descriptor->idVendor == (uint16_t)handle->selected_vendor_id &&
         descriptor->idProduct == (uint16_t)handle->selected_product_id;
}

static void madk_reset_device_fields(madk_libusb_handle *handle) {
  handle->device = NULL;
  handle->vendor_id = -1;
  handle->product_id = -1;
  handle->bulk_in_endpoint = -1;
  handle->bulk_out_endpoint = -1;
  handle->interface_number = -1;
  handle->claimed = 0;
}

static void madk_close_current_device(madk_libusb_handle *handle) {
  if (handle == NULL || handle->device == NULL) {
    if (handle != NULL) madk_reset_device_fields(handle);
    return;
  }
  if (handle->claimed && handle->api.release_interface != NULL &&
      handle->interface_number >= 0) {
    (void)handle->api.release_interface(handle->device, handle->interface_number);
  }
  handle->api.close(handle->device);
  madk_reset_device_fields(handle);
}

static int madk_discover_endpoints(
    madk_libusb_handle *handle,
    madk_libusb_device *device,
    int32_t *bulk_in,
    int32_t *bulk_out,
    int32_t *interface_number) {
  madk_libusb_config_descriptor *config = NULL;
  int result = handle->api.get_active_config_descriptor(device, &config);
  if (result == MADK_LIBUSB_ERROR_NOT_FOUND) {
    result = handle->api.get_config_descriptor(device, 0, &config);
  }
  if (result < 0) {
    if (result == MADK_LIBUSB_ERROR_NOT_FOUND) {
      *bulk_in = -1;
      *bulk_out = -1;
      *interface_number = -1;
      return MADK_STATUS_OK;
    }
    return madk_map_libusb_error(handle, result, "read USB configuration");
  }
  *bulk_in = -1;
  *bulk_out = -1;
  *interface_number = -1;
  if (config != NULL) {
    for (uint8_t i = 0; i < config->bNumInterfaces; i++) {
      const madk_libusb_interface *interface = &config->interface[i];
      for (int32_t alt = 0; alt < interface->num_altsetting; alt++) {
        const madk_libusb_interface_descriptor *setting =
            &interface->altsetting[alt];
        int32_t local_in = -1;
        int32_t local_out = -1;
        for (uint8_t endpoint = 0; endpoint < setting->bNumEndpoints;
             endpoint++) {
          const madk_libusb_endpoint_descriptor *descriptor =
              &setting->endpoint[endpoint];
          if ((descriptor->bmAttributes & 0x03) != 0x02) continue;
          if ((descriptor->bEndpointAddress & 0x80) != 0 && local_in < 0) {
            local_in = descriptor->bEndpointAddress;
          }
          if ((descriptor->bEndpointAddress & 0x80) == 0 && local_out < 0) {
            local_out = descriptor->bEndpointAddress;
          }
        }
        if (local_in >= 0 && *bulk_in < 0) *bulk_in = local_in;
        if (local_out >= 0 && *bulk_out < 0) *bulk_out = local_out;
        if (*interface_number < 0 && (local_in >= 0 || local_out >= 0)) {
          *interface_number = setting->bInterfaceNumber;
        }
        if (*bulk_in >= 0 && *bulk_out >= 0) break;
      }
      if (*bulk_in >= 0 && *bulk_out >= 0) break;
    }
    handle->api.free_config_descriptor(config);
  }
  return MADK_STATUS_OK;
}

static int madk_refresh_once(madk_libusb_handle *handle) {
  madk_close_current_device(handle);
  madk_libusb_device **devices = NULL;
  madk_libusb_ssize_t count =
      handle->api.get_device_list(handle->context, &devices);
  if (count < 0) {
    return madk_map_libusb_error(handle, (int)count, "enumerate USB devices");
  }

  int first_error = MADK_STATUS_NOT_FOUND;
  for (madk_libusb_ssize_t i = 0; i < count; i++) {
    madk_libusb_device_descriptor descriptor;
    memset(&descriptor, 0, sizeof(descriptor));
    int result = handle->api.get_device_descriptor(devices[i], &descriptor);
    if (result < 0) continue;
    if (!madk_matches(handle, &descriptor)) continue;

    madk_libusb_device_handle *opened = NULL;
    result = handle->api.open(devices[i], &opened);
    if (result < 0 || opened == NULL) {
      first_error = madk_map_libusb_error(handle, result, "open USB device");
      continue;
    }

    int32_t bulk_in = -1;
    int32_t bulk_out = -1;
    int32_t interface_number = -1;
    result = madk_discover_endpoints(
        handle, devices[i], &bulk_in, &bulk_out, &interface_number);
    if (result < 0) {
      handle->api.close(opened);
      first_error = result;
      continue;
    }

    handle->device = opened;
    handle->vendor_id = descriptor.idVendor;
    handle->product_id = descriptor.idProduct;
    handle->bulk_in_endpoint = bulk_in;
    handle->bulk_out_endpoint = bulk_out;
    handle->interface_number = interface_number;
    handle->claimed = 0;
    handle->waiting_for_accessory = 0;
    handle->api.free_device_list(devices, 1);
    madk_set_error(handle, "libusb device opened");
    return MADK_STATUS_OK;
  }
  handle->api.free_device_list(devices, 1);
  if (first_error == MADK_STATUS_NOT_FOUND) {
    if (handle->accessory_mode || handle->waiting_for_accessory) {
      madk_set_error(handle,
                     "no allowlisted Android AOA accessory device is connected");
    } else {
      snprintf(handle->error, sizeof(handle->error),
               "no USB device matched the explicit VID 0x%04X and PID 0x%04X",
               handle->selected_vendor_id, handle->selected_product_id);
    }
  }
  return first_error;
}

static void madk_sleep_ms(int32_t milliseconds) {
#if defined(_WIN32)
  Sleep((DWORD)milliseconds);
#else
  struct timespec delay;
  delay.tv_sec = milliseconds / 1000;
  delay.tv_nsec = (long)(milliseconds % 1000) * 1000000L;
  nanosleep(&delay, NULL);
#endif
}

static int madk_refresh_internal(madk_libusb_handle *handle, int wait_for_device) {
  const int attempts = wait_for_device ? 21 : 1;
  for (int attempt = 0; attempt < attempts; attempt++) {
    int result = madk_refresh_once(handle);
    if (result == MADK_STATUS_OK) return MADK_STATUS_OK;
    if (result != MADK_STATUS_NOT_FOUND || attempt + 1 >= attempts) {
      if (wait_for_device && result == MADK_STATUS_NOT_FOUND) {
        madk_set_error(handle,
                       "timed out waiting for Android AOA accessory re-enumeration");
        return MADK_STATUS_DISCONNECTED;
      }
      return result;
    }
    madk_sleep_ms(50);
  }
  return MADK_STATUS_DISCONNECTED;
}

static int madk_ensure_claimed(madk_libusb_handle *handle) {
  if (handle->claimed) return MADK_STATUS_OK;
  if (handle->interface_number < 0) {
    madk_set_error(handle, "the selected USB configuration has no bulk interface");
    return MADK_STATUS_INVALID_ENDPOINT;
  }
  if (handle->api.set_auto_detach != NULL) {
    (void)handle->api.set_auto_detach(handle->device, 1);
  }
  int result = handle->api.claim_interface(handle->device, handle->interface_number);
  if (result < 0) {
    return madk_map_libusb_error(handle, result, "claim USB interface");
  }
  handle->claimed = 1;
  return MADK_STATUS_OK;
}

static int madk_validate_common(
    madk_libusb_handle *handle, int32_t length, int32_t timeout_ms) {
  if (handle == NULL || handle->closed) return MADK_STATUS_CLOSED;
  if (handle->device == NULL) return MADK_STATUS_DISCONNECTED;
  if (length < 0) {
    madk_set_error(handle, "transfer length must not be negative");
    return MADK_STATUS_INVALID_LENGTH;
  }
  if (timeout_ms <= 0 || (uint32_t)timeout_ms > UINT_MAX) {
    madk_set_error(handle, "transfer timeout must be positive and fit in uint32");
    return MADK_STATUS_INVALID_ARGUMENT;
  }
  return MADK_STATUS_OK;
}

static void madk_libusb_finalize(void *value) {
  madk_libusb_close_impl((madk_libusb_handle *)value);
}

MOONBIT_FFI_EXPORT madk_libusb_handle *madk_libusb_new(void) {
  madk_libusb_handle *handle = (madk_libusb_handle *)moonbit_make_external_object(
      madk_libusb_finalize, sizeof(madk_libusb_handle));
  if (handle == NULL) return NULL;
  memset(handle, 0, sizeof(*handle));
  handle->selected_vendor_id = -1;
  handle->selected_product_id = -1;
  handle->vendor_id = -1;
  handle->product_id = -1;
  handle->bulk_in_endpoint = -1;
  handle->bulk_out_endpoint = -1;
  handle->interface_number = -1;
  madk_set_error(handle, "transport is not open");
  return handle;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_open(
    madk_libusb_handle *handle,
    int32_t vendor_id,
    int32_t product_id,
    int32_t accessory_mode) {
  if (handle == NULL) return MADK_STATUS_INVALID_ARGUMENT;
  if (handle->closed) return MADK_STATUS_CLOSED;
  if (vendor_id < 0 || vendor_id > 0xFFFF ||
      (!accessory_mode && (product_id < 0 || product_id > 0xFFFF))) {
    madk_set_error(handle, "USB selector VID/PID is outside the 16-bit range");
    return MADK_STATUS_INVALID_ARGUMENT;
  }
  int result = madk_load_api(&handle->api);
  if (result < 0) {
    madk_set_error(handle, madk_runtime_error);
    return result;
  }
  result = handle->api.init(&handle->context);
  if (result < 0) {
    int status = madk_map_libusb_error(handle, result, "initialize libusb");
    madk_unload_library(handle->api.library);
    madk_clear_api(&handle->api);
    return status;
  }
  handle->selected_vendor_id = vendor_id;
  handle->selected_product_id = product_id;
  handle->accessory_mode = accessory_mode != 0;
  handle->closed = 0;
  result = madk_refresh_internal(handle, 0);
  if (result < 0) {
    madk_close_current_device(handle);
    if (handle->context != NULL && handle->api.exit != NULL) {
      handle->api.exit(handle->context);
      handle->context = NULL;
    }
    madk_unload_library(handle->api.library);
    madk_clear_api(&handle->api);
    return result;
  }
  return MADK_STATUS_OK;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_info(madk_libusb_handle *handle) {
  if (handle == NULL || handle->closed) return MADK_STATUS_CLOSED;
  if (handle->device == NULL) {
    return madk_refresh_internal(handle, handle->waiting_for_accessory);
  }
  if (handle->waiting_for_accessory) {
    return madk_refresh_internal(handle, 1);
  }
  return MADK_STATUS_OK;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_refresh(madk_libusb_handle *handle) {
  if (handle == NULL || handle->closed) return MADK_STATUS_CLOSED;
  return madk_refresh_internal(handle, handle->waiting_for_accessory);
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_vendor_id(madk_libusb_handle *handle) {
  return handle == NULL ? -1 : handle->vendor_id;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_product_id(madk_libusb_handle *handle) {
  return handle == NULL ? -1 : handle->product_id;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_bulk_in_endpoint(
    madk_libusb_handle *handle) {
  return handle == NULL ? -1 : handle->bulk_in_endpoint;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_bulk_out_endpoint(
    madk_libusb_handle *handle) {
  return handle == NULL ? -1 : handle->bulk_out_endpoint;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_control(
    madk_libusb_handle *handle,
    int32_t request_type,
    int32_t request,
    int32_t value,
    int32_t index,
    moonbit_bytes_t data,
    int32_t length,
    int32_t timeout_ms) {
  int result = madk_validate_common(handle, length, timeout_ms);
  if (result < 0) return result;
  if (request_type < 0 || request_type > 0xFF || request < 0 || request > 0xFF ||
      value < 0 || value > 0xFFFF || index < 0 || index > 0xFFFF ||
      length > 0xFFFF || data == NULL || Moonbit_array_length(data) < length) {
    madk_set_error(handle, "invalid USB control transfer fields");
    return MADK_STATUS_INVALID_ARGUMENT;
  }
  result = handle->api.control_transfer(
      handle->device, (uint8_t)request_type, (uint8_t)request,
      (uint16_t)value, (uint16_t)index, (unsigned char *)data,
      (uint16_t)length, (unsigned int)timeout_ms);
  if (result < 0) {
    int status = madk_map_libusb_error(handle, result, "USB control transfer");
    return status;
  }
  if ((request_type & 0x80) == 0 && request == 53 && value == 0 && index == 0) {
    handle->waiting_for_accessory = 1;
  }
  return result;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_bulk_write(
    madk_libusb_handle *handle,
    int32_t endpoint,
    moonbit_bytes_t data,
    int32_t length,
    int32_t timeout_ms) {
  int result = madk_validate_common(handle, length, timeout_ms);
  if (result < 0) return result;
  if (endpoint < 0 || endpoint > 0xFF || data == NULL ||
      Moonbit_array_length(data) < length) {
    madk_set_error(handle, "invalid USB bulk write fields");
    return endpoint < 0 || endpoint > 0xFF ? MADK_STATUS_INVALID_ENDPOINT
                                           : MADK_STATUS_INVALID_ARGUMENT;
  }
  if (endpoint != handle->bulk_out_endpoint) {
    madk_set_error(handle, "bulk write endpoint is not in the active configuration");
    return MADK_STATUS_INVALID_ENDPOINT;
  }
  result = madk_ensure_claimed(handle);
  if (result < 0) return result;
  int actual = 0;
  result = handle->api.bulk_transfer(
      handle->device, (uint8_t)endpoint, (unsigned char *)data, length, &actual,
      (unsigned int)timeout_ms);
  if (result < 0) return madk_map_libusb_error(handle, result, "USB bulk write");
  return actual;
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_bulk_read(
    madk_libusb_handle *handle,
    int32_t endpoint,
    moonbit_bytes_t data,
    int32_t length,
    int32_t timeout_ms) {
  int result = madk_validate_common(handle, length, timeout_ms);
  if (result < 0) return result;
  if (endpoint < 0 || endpoint > 0xFF || length <= 0 || data == NULL ||
      Moonbit_array_length(data) < length) {
    madk_set_error(handle, "invalid USB bulk read fields");
    return endpoint < 0 || endpoint > 0xFF ? MADK_STATUS_INVALID_ENDPOINT
           : MADK_STATUS_INVALID_LENGTH;
  }
  if (endpoint != handle->bulk_in_endpoint) {
    madk_set_error(handle, "bulk read endpoint is not in the active configuration");
    return MADK_STATUS_INVALID_ENDPOINT;
  }
  result = madk_ensure_claimed(handle);
  if (result < 0) return result;
  int actual = 0;
  result = handle->api.bulk_transfer(
      handle->device, (uint8_t)endpoint, (unsigned char *)data, length, &actual,
      (unsigned int)timeout_ms);
  if (result < 0) return madk_map_libusb_error(handle, result, "USB bulk read");
  return actual;
}

static void madk_libusb_close_impl(madk_libusb_handle *handle) {
  if (handle == NULL || handle->closed) return;
  madk_close_current_device(handle);
  if (handle->context != NULL && handle->api.exit != NULL) {
    handle->api.exit(handle->context);
    handle->context = NULL;
  }
  if (handle->api.library != NULL) {
    madk_unload_library(handle->api.library);
  }
  madk_clear_api(&handle->api);
  handle->closed = 1;
  handle->waiting_for_accessory = 0;
  madk_set_error(handle, "transport is closed");
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_close(madk_libusb_handle *handle) {
  if (handle == NULL) return MADK_STATUS_INVALID_ARGUMENT;
  madk_libusb_close_impl(handle);
  return MADK_STATUS_OK;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t madk_libusb_last_error(
    madk_libusb_handle *handle) {
  return madk_text(handle == NULL ? "invalid libusb handle" : handle->error);
}

MOONBIT_FFI_EXPORT int32_t madk_libusb_runtime_available(void) {
  madk_libusb_api api;
  int result = madk_load_api(&api);
  if (result == MADK_STATUS_OK) {
    madk_unload_library(api.library);
    return 1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t madk_libusb_runtime_diagnostic(void) {
  madk_libusb_api api;
  int result = madk_load_api(&api);
  if (result == MADK_STATUS_OK) {
    madk_unload_library(api.library);
    madk_set_runtime_error(
        "libusb 1.0 runtime is available; USB access still requires an "
        "allowlisted device and host permissions");
  }
  return madk_text(madk_runtime_error);
}
