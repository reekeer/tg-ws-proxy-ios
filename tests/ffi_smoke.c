#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int32_t StartProxy(
    const char *host,
    int32_t port,
    const char *dc_ips,
    const char *secret,
    int32_t verbose
);
int32_t StopProxy(void);
char *GetStats(void);
void FreeString(char *pointer);

int main(void) {
    const char *secret = "0123456789abcdef0123456789abcdef";
    /* Не 1443: на машине разработчика этот порт уже держит само приложение. */
    const char *port_env = getenv("TGWS_SMOKE_PORT");
    int32_t port = port_env != NULL ? (int32_t)strtol(port_env, NULL, 10) : 34443;
    int32_t started = StartProxy("127.0.0.1", port, "", secret, 0);
    if (started != 0) {
        fprintf(stderr, "StartProxy returned %d\n", started);
    }
    assert(started == 0);

    char *stats = GetStats();
    assert(stats != NULL);
    assert(strstr(stats, "active=0") != NULL);
    printf("%s\n", stats);
    FreeString(stats);

    assert(StopProxy() == 0);
    return EXIT_SUCCESS;
}
