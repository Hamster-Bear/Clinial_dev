source('modules/common/analysis_shared.R')

# Force broom::tidy to fail
broom::tidy <- function(...) stop("Simulated failure")

fit_glm <- glm(am ~ wt + cyl, data = mtcars, family = binomial())
tid_fail <- extract_broom_tidy_with_fallback(fit_glm, conf.int = FALSE, exponentiate = TRUE, add_note_fn = print)
print("Fallback Results:")
print(tid_fail)
