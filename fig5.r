library(ggplot2)
library(dplyr)
library(readr)
library(patchwork)

# Leitura do CSV
df <- read_delim("./data/times-SchedPQ.csv", delim = ";")

# Agrupar por P, Q e scheduler, calculando a média e o desvio padrão do tempo
df_summary <- df %>%
  group_by(P, Q, scheduler) %>%
  summarise(
    mean_time = mean(time),
    sd_time = sd(time),
    .groups = "drop"
  )

# Calcular o limite superior máximo para o eixo (para manter o eixo igual)
y_max <- max(df_summary$mean_time + df_summary$sd_time)

# Criar um gráfico para cada combinação de P e Q
plots <- df_summary %>%
  split(.$P * 1000 + .$Q) %>%
  lapply(function(subdf) {
    pq_label <- paste0("P = ", subdf$P[1], ", Q = ", subdf$Q[1])
    ggplot(subdf, aes(x = scheduler, y = mean_time, fill = scheduler)) +
      geom_col(show.legend = FALSE) +
      geom_errorbar(
        aes(ymin = mean_time - sd_time, ymax = mean_time + sd_time),
        width = 0.2
      ) +
      coord_flip() +
      scale_y_continuous(limits = c(0, y_max)) +  # garantir o mesmo eixo
      labs(
        title = pq_label,
        y = "Mean time (s)",
        x = "Scheduler"
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
ggsave("fig5.png", final_plot, width = 16, height = 4 * ceiling(length(plots)/2), dpi = 300)

