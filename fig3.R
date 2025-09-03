library(ggplot2)
data <- read.csv("./data/block-def.csv", sep = ";")
ggplot(data, aes(x = factor(nb), y = time)) +
  geom_boxplot(fill = "skyblue") +
  labs(title = "LU Factorization Time by nb",
       x = "nb",
       y = "Time (seconds)") +
  theme_minimal()

