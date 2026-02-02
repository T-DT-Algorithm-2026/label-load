#include "my_application.h"

#include <stdlib.h>

static void atk_log_handler(const gchar *log_domain, GLogLevelFlags log_level,
                            const gchar *message, gpointer user_data) {
  // Do nothing to suppress the message
}

int main(int argc, char **argv) {
  setenv("NO_AT_BRIDGE", "1", 1);
  setenv("GTK_MODULES", "", 1);

  // Register log handler for Atk domain to suppress criticals and warnings
  g_log_set_handler(
      "Atk", (GLogLevelFlags)(G_LOG_LEVEL_CRITICAL | G_LOG_LEVEL_WARNING),
      atk_log_handler, NULL);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
