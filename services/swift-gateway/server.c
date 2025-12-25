#define _POSIX_C_SOURCE 200809L
#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <stdarg.h>
#include <errno.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <microhttpd.h>
#include <json-c/json.h>

#define PORT 8086
#define MAX_BODY_SIZE 4096
#define MT103_BINARY "/bin/mt103-generator"
#define MAX_MT103_OUTPUT 2048

// Logging helper with timestamp
void log_msg(const char *level, const char *format, ...) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    struct tm *tm_info = localtime(&tv.tv_sec);
    
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
    fprintf(stderr, "[%s.%03ld] [swift-gateway] [%s] ", 
            timestamp, tv.tv_usec / 1000, level);
    
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fprintf(stderr, "\n");
    fflush(stderr);
}

#define LOG_INFO(...) log_msg("INFO", __VA_ARGS__)
#define LOG_ERROR(...) log_msg("ERROR", __VA_ARGS__)
#define LOG_WARN(...) log_msg("WARN", __VA_ARGS__)
#define LOG_DEBUG(...) log_msg("DEBUG", __VA_ARGS__)

// Format string to fixed width (pad or truncate)
void format_fixed_width(char *dest, const char *src, size_t width) {
    size_t len = strlen(src);
    if (len >= width) {
        memcpy(dest, src, width);
    } else {
        memcpy(dest, src, len);
        memset(dest + len, ' ', width - len);
    }
    dest[width] = '\0';
}

// Generate reference ID
void generate_reference(char *ref, size_t ref_size) {
    time_t now = time(NULL);
    snprintf(ref, ref_size, "TRANSFERX-%ld", now);
    // Pad to 35 chars
    size_t len = strlen(ref);
    if (len < 35) {
        memset(ref + len, ' ', 35 - len);
        ref[35] = '\0';
    }
}

// Execute mt103-generator and capture output
int execute_mt103(const char *sender_id, const char *recipient_id, 
                 double amount, const char *currency, const char *reference,
                 char *output, size_t output_size) {
    LOG_DEBUG("Executing MT103 generator: senderId=%.20s, recipientId=%.20s, amount=%.2f, currency=%.3s", 
              sender_id, recipient_id, amount, currency);
    
    // Format input as fixed-width string
    char formatted_input[94]; // 20 + 20 + 15.2 + 3 + 35 + newline = 94
    char sender_fixed[21], recipient_fixed[21], currency_fixed[4], ref_fixed[36];
    
    format_fixed_width(sender_fixed, sender_id, 20);
    format_fixed_width(recipient_fixed, recipient_id, 20);
    format_fixed_width(currency_fixed, currency ? currency : "USD", 3);
    format_fixed_width(ref_fixed, reference, 35);
    
    // Format amount as 15.2 (15 digits, 2 decimals)
    char amount_str[18];
    snprintf(amount_str, sizeof(amount_str), "%015.2f", amount);
    
    snprintf(formatted_input, sizeof(formatted_input), "%-20s%-20s%s%-3s%-35s\n",
             sender_fixed, recipient_fixed, amount_str, currency_fixed, ref_fixed);
    
    LOG_DEBUG("Formatted input: %s", formatted_input);
    
    // Use temp file and fork/exec with proper stdin/stdout redirection
    char tmpfile_template[] = "/tmp/mt103_input_XXXXXX";
    int tmpfd = mkstemp(tmpfile_template);
    if (tmpfd == -1) {
        LOG_ERROR("Failed to create temporary file: %s", strerror(errno));
        return -1;
    }
    
    ssize_t written = write(tmpfd, formatted_input, strlen(formatted_input));
    close(tmpfd);
    
    if (written == -1 || (size_t)written != strlen(formatted_input)) {
        LOG_ERROR("Failed to write to temporary file: %s", strerror(errno));
        unlink(tmpfile_template);
        return -1;
    }
    
    // Create pipe for reading output
    int read_pipe[2];
    if (pipe(read_pipe) == -1) {
        LOG_ERROR("Failed to create read pipe: %s", strerror(errno));
        unlink(tmpfile_template);
        return -1;
    }
    
    pid_t child_pid = fork();
    size_t total_read = 0;
    
    if (child_pid == 0) {
        // Child: redirect stdin from file, stdout to pipe
        close(read_pipe[0]);
        dup2(read_pipe[1], STDOUT_FILENO);
        close(read_pipe[1]);
        
        int input_fd = open(tmpfile_template, O_RDONLY);
        if (input_fd == -1) {
            exit(1);
        }
        dup2(input_fd, STDIN_FILENO);
        close(input_fd);
        
        execl(MT103_BINARY, MT103_BINARY, (char *)NULL);
        exit(1);
    } else {
        close(read_pipe[1]);
        
        // Read output
        output[0] = '\0';
        char buffer[256];
        ssize_t n;
        
        while ((n = read(read_pipe[0], buffer, sizeof(buffer) - 1)) > 0 && total_read < output_size - 1) {
            // Filter out non-printable characters except newlines and tabs
            size_t filtered_len = 0;
            for (ssize_t i = 0; i < n && filtered_len < sizeof(buffer) - 1; i++) {
                unsigned char c = buffer[i];
                if (c >= 32 || c == '\n' || c == '\t' || c == '\r') {
                    buffer[filtered_len++] = c;
                }
            }
            buffer[filtered_len] = '\0';
            
            size_t copy_len = (total_read + filtered_len < output_size - 1) ? filtered_len : (output_size - total_read - 1);
            strncat(output, buffer, copy_len);
            total_read += copy_len;
        }
        close(read_pipe[0]);
        
        int status;
        waitpid(child_pid, &status, 0);
        unlink(tmpfile_template);
        
        if (status != 0) {
            LOG_ERROR("MT103 generator exited with status %d", WEXITSTATUS(status));
            return -1;
        }
    }
    
    LOG_INFO("MT103 generated successfully: %zu bytes", total_read);
    LOG_DEBUG("MT103 output: %s", output);
    
    return 0;
}

// HTTP request handler
static enum MHD_Result handle_request(void *cls, struct MHD_Connection *connection,
                         const char *url, const char *method,
                         const char *version, const char *upload_data,
                         size_t *upload_data_size, void **con_cls) {
    
    (void)cls;
    (void)version;
    
    LOG_INFO("Request: %s %s", method, url);
    
    // Handle health check
    if (strcmp(method, "GET") == 0 && strcmp(url, "/health") == 0) {
        LOG_DEBUG("Health check requested");
        const char *response = "{\"status\":\"healthy\",\"service\":\"swift-gateway\"}";
        struct MHD_Response *mhd_response = MHD_create_response_from_buffer(
            strlen(response), (void *)response, MHD_RESPMEM_PERSISTENT);
        MHD_add_response_header(mhd_response, "Content-Type", "application/json");
        enum MHD_Result ret = MHD_queue_response(connection, MHD_HTTP_OK, mhd_response);
        MHD_destroy_response(mhd_response);
        return ret;
    }
    
    // Handle POST /generate
    if (strcmp(method, "POST") == 0 && strcmp(url, "/generate") == 0) {
        if (*con_cls == NULL) {
            // First call - allocate buffer for request body
            *con_cls = malloc(MAX_BODY_SIZE);
            if (!*con_cls) {
                LOG_ERROR("Failed to allocate memory for request body");
                return MHD_NO;
            }
            ((char *)*con_cls)[0] = '\0';
            return MHD_YES;
        }
        
        // Read request body
        if (*upload_data_size > 0) {
            char *body = (char *)*con_cls;
            size_t current_len = strlen(body);
            if (current_len + *upload_data_size < MAX_BODY_SIZE) {
                memcpy(body + current_len, upload_data, *upload_data_size);
                body[current_len + *upload_data_size] = '\0';
            }
            *upload_data_size = 0;
            return MHD_YES;
        }
        
        // Process request
        char *body = (char *)*con_cls;
        LOG_DEBUG("Request body: %s", body);
        
        // Parse JSON
        json_object *json = json_tokener_parse(body);
        if (!json) {
            LOG_ERROR("Failed to parse JSON: %s", body);
            const char *error = "{\"error\":\"Invalid JSON\"}";
            struct MHD_Response *mhd_response = MHD_create_response_from_buffer(
                strlen(error), (void *)error, MHD_RESPMEM_PERSISTENT);
            MHD_add_response_header(mhd_response, "Content-Type", "application/json");
            enum MHD_Result ret = MHD_queue_response(connection, MHD_HTTP_BAD_REQUEST, mhd_response);
            MHD_destroy_response(mhd_response);
            free(*con_cls);
            *con_cls = NULL;
            return ret;
        }
        
        // Extract fields
        json_object *sender_id_obj, *recipient_id_obj, *amount_obj, *currency_obj;
        const char *sender_id = NULL, *recipient_id = NULL, *currency = NULL;
        double amount = 0.0;
        
        if (json_object_object_get_ex(json, "senderId", &sender_id_obj)) {
            sender_id = json_object_get_string(sender_id_obj);
        }
        if (json_object_object_get_ex(json, "recipientId", &recipient_id_obj)) {
            recipient_id = json_object_get_string(recipient_id_obj);
        }
        if (json_object_object_get_ex(json, "amount", &amount_obj)) {
            amount = json_object_get_double(amount_obj);
        }
        if (json_object_object_get_ex(json, "currency", &currency_obj)) {
            currency = json_object_get_string(currency_obj);
        }
        
        if (!sender_id || !recipient_id || amount <= 0) {
            LOG_ERROR("Missing required fields: senderId=%s, recipientId=%s, amount=%.2f", 
                      sender_id ? sender_id : "NULL", 
                      recipient_id ? recipient_id : "NULL", 
                      amount);
            const char *error = "{\"error\":\"Missing required fields: senderId, recipientId, amount\"}";
            struct MHD_Response *mhd_response = MHD_create_response_from_buffer(
                strlen(error), (void *)error, MHD_RESPMEM_PERSISTENT);
            MHD_add_response_header(mhd_response, "Content-Type", "application/json");
            enum MHD_Result ret = MHD_queue_response(connection, MHD_HTTP_BAD_REQUEST, mhd_response);
            MHD_destroy_response(mhd_response);
            json_object_put(json);
            free(*con_cls);
            *con_cls = NULL;
            return ret;
        }
        
        LOG_INFO("Processing SWIFT transfer: senderId=%s, recipientId=%s, amount=%.2f, currency=%s",
                 sender_id, recipient_id, amount, currency ? currency : "USD");
        
        // Generate reference
        char reference[36];
        generate_reference(reference, sizeof(reference));
        
        // Execute MT103 generator
        char mt103_output[MAX_MT103_OUTPUT];
        int result = execute_mt103(sender_id, recipient_id, amount, currency, reference, 
                                   mt103_output, sizeof(mt103_output));
        
        if (result != 0) {
            LOG_ERROR("Failed to generate MT103 message");
            const char *error = "{\"error\":\"Failed to generate MT103 message\"}";
            struct MHD_Response *mhd_response = MHD_create_response_from_buffer(
                strlen(error), (void *)error, MHD_RESPMEM_PERSISTENT);
            MHD_add_response_header(mhd_response, "Content-Type", "application/json");
            enum MHD_Result ret = MHD_queue_response(connection, MHD_HTTP_INTERNAL_SERVER_ERROR, mhd_response);
            MHD_destroy_response(mhd_response);
            json_object_put(json);
            free(*con_cls);
            *con_cls = NULL;
            return ret;
        }
        
        // Extract ID from reference (remove padding)
        char id[64];
        char ref_trimmed[36];
        // Copy reference and trim spaces
        strncpy(ref_trimmed, reference, sizeof(ref_trimmed) - 1);
        ref_trimmed[sizeof(ref_trimmed) - 1] = '\0';
        // Trim trailing spaces
        size_t len = strlen(ref_trimmed);
        while (len > 0 && ref_trimmed[len - 1] == ' ') {
            ref_trimmed[--len] = '\0';
        }
        // Find the timestamp part (after TRANSFERX-)
        char *timestamp_start = strstr(ref_trimmed, "TRANSFERX-");
        if (timestamp_start) {
            timestamp_start += strlen("TRANSFERX-");
            // Extract just the number part
            char *space_pos = strchr(timestamp_start, ' ');
            if (space_pos) {
                *space_pos = '\0';
            }
            snprintf(id, sizeof(id), "SWIFT-TRANSFERX-%s", timestamp_start);
        } else {
            // Fallback: use the trimmed reference
            snprintf(id, sizeof(id), "SWIFT-%.20s", ref_trimmed);
        }
        
        // Clean MT103 output - skip to first '{' which is the start of MT103 format
        char *clean_output = mt103_output;
        while (*clean_output && *clean_output != '{') {
            clean_output++;
        }
        // If we didn't find '{', use the original (might be empty or malformed)
        if (!*clean_output) {
            clean_output = mt103_output;
        }
        
        // Build response JSON
        json_object *response = json_object_new_object();
        json_object_object_add(response, "mt103", json_object_new_string(clean_output));
        json_object_object_add(response, "reference", json_object_new_string(ref_trimmed));
        json_object_object_add(response, "id", json_object_new_string(id));
        
        const char *response_str = json_object_to_json_string(response);
        LOG_INFO("SWIFT transfer processed successfully: id=%s, reference=%s", id, ref_trimmed);
        LOG_DEBUG("Response JSON: %s", response_str);
        
        // Create a clean copy of the response string to avoid any issues
        size_t response_len = strlen(response_str);
        char *clean_response = malloc(response_len + 1);
        if (!clean_response) {
            LOG_ERROR("Failed to allocate memory for response");
            json_object_put(response);
            free(*con_cls);
            *con_cls = NULL;
            const char *error = "{\"error\":\"Internal server error\"}";
            struct MHD_Response *mhd_response = MHD_create_response_from_buffer(
                strlen(error), (void *)error, MHD_RESPMEM_PERSISTENT);
            MHD_add_response_header(mhd_response, "Content-Type", "application/json");
            enum MHD_Result ret = MHD_queue_response(connection, MHD_HTTP_INTERNAL_SERVER_ERROR, mhd_response);
            MHD_destroy_response(mhd_response);
            return ret;
        }
        memcpy(clean_response, response_str, response_len + 1);
        
        struct MHD_Response *mhd_response = MHD_create_response_from_buffer(
            response_len, clean_response, MHD_RESPMEM_MUST_FREE);
        MHD_add_response_header(mhd_response, "Content-Type", "application/json");
        enum MHD_Result ret = MHD_queue_response(connection, MHD_HTTP_OK, mhd_response);
        MHD_destroy_response(mhd_response);
        
        json_object_put(response);
        json_object_put(json);
        free(*con_cls);
        *con_cls = NULL;
        return ret;
    }
    
    // 404 for unknown endpoints
    LOG_WARN("Unknown endpoint: %s %s", method, url);
    const char *not_found = "{\"error\":\"Not found\"}";
    struct MHD_Response *mhd_response = MHD_create_response_from_buffer(
        strlen(not_found), (void *)not_found, MHD_RESPMEM_PERSISTENT);
    MHD_add_response_header(mhd_response, "Content-Type", "application/json");
    enum MHD_Result ret = MHD_queue_response(connection, MHD_HTTP_NOT_FOUND, mhd_response);
    MHD_destroy_response(mhd_response);
    return ret;
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;
    
    int port = PORT;
    const char *port_env = getenv("PORT");
    if (port_env) {
        port = atoi(port_env);
        if (port <= 0 || port > 65535) {
            LOG_ERROR("Invalid PORT environment variable: %s", port_env);
            port = PORT;
        }
    }
    
    LOG_INFO("Starting SWIFT Gateway HTTP server on port %d", port);
    
    struct MHD_Daemon *daemon = MHD_start_daemon(
        MHD_USE_INTERNAL_POLLING_THREAD,
        port,
        NULL, NULL,
        &handle_request, NULL,
        MHD_OPTION_END);
    
    if (!daemon) {
        LOG_ERROR("Failed to start HTTP server");
        return 1;
    }
    
    LOG_INFO("SWIFT Gateway HTTP server started successfully");
    
    // Keep running until interrupted
    while (1) {
        sleep(1);
    }
    
    LOG_INFO("Shutting down SWIFT Gateway HTTP server");
    MHD_stop_daemon(daemon);
    return 0;
}

