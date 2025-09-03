library(ggplot2)
library(dplyr)
library(readr)
library(patchwork)

# Leitura do CSV
df <- read_delim("times-SchedPQ.csv", delim = ";")

# Criar coluna com rótulo de P x Q
df <- df %>%
  mutate(PQ = paste0("P = ", P, ", Q = ", Q))

# Agrupar por scheduler e PQ, calculando a média e desvio padrão
df_summary <- df %>%
  group_by(scheduler, PQ) %>%
  summarise(
    mean_time = mean(time),
    sd_time = sd(time),
    .groups = "drop"
  )

# Calcular o limite superior para o eixo Y (horizontal após coord_flip)
y_max <- max(df_summary$mean_time + df_summary$sd_time)

# Criar um gráfico para cada scheduler
plots <- df_summary %>%
  split(.$scheduler) %>%
  lapply(function(subdf) {
    sched_label <- paste("Scheduler:", subdf$scheduler[1])
    ggplot(subdf, aes(x = PQ, y = mean_time, fill = PQ)) +
      geom_col(show.legend = FALSE) +
      geom_errorbar(
        aes(ymin = mean_time - sd_time, ymax = mean_time + sd_time),
        width = 0.2
      ) +
      coord_flip() +
      scale_y_continuous(limits = c(0, y_max)) +  # padroniza o eixo
      labs(
        title = sched_label,
        y = "Mean time (s)",
        x = "P × Q Configuration"
      ) +
      theme_minimal(base_size = 14) +
      theme(
        plot.title = element_text(size = 18),
        axis.title.x = element_text(size = 16),
        axis.title.y = element_text(size = 16),
        axis.text = element_text(size = 12)
      )
  })

# Juntar os gráficos (em 1 coluna)
final_plot <- wrap_plots(plots, ncol = 1)

# Salvar como imagem
ggsave(
  "fig6.png",
  final_plot,
  width = 24,
  height = 3 * length(plots),
  dpi = 300
)

