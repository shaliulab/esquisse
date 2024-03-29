
#' Generate code to create a \code{ggplot2}
#'
#' @param data Character. Name of the \code{data.frame}.
#' @param mapping List. Named list of aesthetics.
#' @param geom Character. Name of the geom to use (with or without "geom_").
#' @param geom_args List. Arguments to use in the geom.
#' @param scales Character vector. Scale(s) to use (with or without "scale_").
#' @param scales_args List. Arguments to use in scale(s),
#'  if \code{scales} is length > 1, must be a named list with \code{scales} names.
#' @param coord Character. Coordinates to use (with or without "coord_").
#' @param labs List. Named list of labels to use for title, subtitle, x & y axis, legends.
#' @param theme Character. Name of the theme to use (with or without "theme_").
#' @param theme_args Named list. Arguments for \code{\link[ggplot2:theme]{theme}}.
#' @param facet Character vector. Names of variables to use in \code{\link[ggplot2]{facet_wrap}}.
#' @param facet_row Character vector. Names of row variables to use in \code{\link[ggplot2]{facet_grid}}.
#' @param facet_col Character vector. Names of col variables to use in \code{\link[ggplot2]{facet_grid}}.
#' @param facet_args Named list. Arguments for \code{\link[ggplot2:facet_wrap]{facet_wrap}}.
#' @param xlim A vector of length 2 representing limits on x-axis.
#' @param ylim A vector of length 2 representing limits on y-axis.
#'
#' @return a \code{call} that can be evaluated with \code{eval}.
#' @export
#' 
#' @importFrom stats setNames
#' @importFrom rlang sym syms expr as_name is_call call2 has_length
#' @importFrom ggplot2 ggplot aes theme facet_wrap vars coord_flip labs
#'
#' @example examples/ex-ggcall.R
ggcall <- function(data = NULL,
                   mapping = NULL, 
                   geom = NULL, 
                   geom_args = list(),
                   scales = NULL, 
                   scales_args = list(),
                   coord = NULL, 
                   labs = list(), 
                   theme = NULL, 
                   theme_args = list(),
                   facet = NULL,
                   facet_row = NULL,
                   facet_col = NULL,
                   facet_args = list(),
                   xlim = NULL,
                   ylim = NULL) {
  if (is.null(data))
    return(expr(ggplot()))
  data <- as.character(data)
  if (grepl("::", data)) {
    data <- str2lang(data) 
  } else {
    data <- sym(data)
  }
  if (rlang::is_call(mapping)) 
    mapping <- eval(mapping)
  mapping <- dropNulls(mapping)
  aes <- expr(aes(!!!syms2(mapping)))
  ggcall <- expr(ggplot(!!data) + !!aes)
  if (length(geom) == 1)
    geom_args <- setNames(list(geom_args), geom)
  for (g in geom) {
    g_args <- dropNulls(geom_args[[g]])
    if (!grepl("^geom_", g))
      g <- paste0("geom_", g)
    geom <- call2(g, !!!g_args)
    ggcall <- expr(!!ggcall + !!geom)
  }
  if (!is.null(scales)) {
    if (length(scales) == 1 && !isTRUE(grepl(scales, names(scales_args))))
      scales_args <- setNames(list(scales_args), scales)
    for (s in scales) {
      s_args <- dropNulls(scales_args[[s]])
      if (grepl("::", x = s)) {
        scl <- strsplit(x = s, split = "::")[[1]]
        scl <- call2(scl[2], !!!s_args, .ns = scl[1])
      } else {
        if (!grepl("^scale_", s))
          s <- paste0("scale_", s)
        scl <- call2(s, !!!s_args)
      }
      ggcall <- expr(!!ggcall + !!scl)
    }
  }
  labs <- dropNullsOrEmpty(labs)
  if (length(labs) > 0) {
    labs <- expr(labs(!!!labs))
    ggcall <- expr(!!ggcall + !!labs)
  }
  if (!is.null(coord)) {
    if (!grepl("^coord_", coord))
      coord <- paste0("coord_", coord)
    coord <- call2(coord)
    ggcall <- expr(!!ggcall + !!coord)
  }
  if (!is.null(theme)) {
    if (grepl("::", x = theme)) {
      theme <- strsplit(x = theme, split = "::")[[1]]
      theme <- call2(theme[2], .ns = theme[1])
    } else {
      if (!grepl("^theme_", theme))
        theme <- paste0("theme_", theme)
      theme <- call2(theme)
    }
    ggcall <- expr(!!ggcall + !!theme)
  }
  if (!any(c("fill", "colour", "color", "size", "shape") %in% names(mapping))) {
    theme_args$legend.position <- NULL
  }
  theme_args <- dropNullsOrEmpty(theme_args)
  if (length(theme_args) > 0) {
    theme_args <- call2("theme", !!!theme_args)
    ggcall <- expr(!!ggcall + !!theme_args)
  }
  if (!is.null(facet)) {
    facet_args <- dropNullsOrEmpty(facet_args)
    if (length(facet_args) > 0) {
      facet <- expr(facet_wrap(vars(!!!syms(facet)), !!!facet_args))
      ggcall <- expr(!!ggcall + !!facet)
    } else {
      facet <- expr(facet_wrap(vars(!!!syms(facet))))
      ggcall <- expr(!!ggcall + !!facet)
    }
  } else if (!is.null(facet_row) | !is.null(facet_col)) {
    facet_args$ncol <- NULL
    facet_args$nrow <- NULL
    facet_args <- dropNullsOrEmpty(facet_args)
    if (length(facet_args) > 0) {
      facet <- expr(facet_grid(vars(!!!syms(facet_row)), vars(!!!syms(facet_col)), !!!facet_args))
      ggcall <- expr(!!ggcall + !!facet)
    } else {
      facet <- expr(facet_grid(vars(!!!syms(facet_row)), vars(!!!syms(facet_col))))
      ggcall <- expr(!!ggcall + !!facet)
    }
  }
  
  if (has_length(xlim, 2)) {
    xlim <- expr(xlim(!!!as.list(xlim)))
    ggcall <- expr(!!ggcall + !!xlim)
  }
  if (has_length(ylim, 2)) {
    ylim <- expr(ylim(!!!as.list(ylim)))
    ggcall <- expr(!!ggcall + !!ylim)
  }
  
  ggcall
}

#' @importFrom ggetho scale_x_hours scale_x_days
#' @importFrom rlang env_poke
extend_gg_call <- function(ggcall, x_unit=NULL, y_unit=NULL, z_aes=NULL) {
  if (!is.null(x_unit)) {
    message("Adjusting X axis")
    scale_x_timeunit <- list("hours" = ggetho::scale_x_hours, "days" = ggetho::scale_x_days)[[x_unit]]
    scale_x <- expr(scale_x_timeunit())
    rlang::env_poke(env = parent.frame(), nm = "scale_x_timeunit", scale_x_timeunit)
    ggcall <- expr(!!ggcall + !!scale_x)
  }
  
  # TODO This is a mess
  # It only works because everytie z_aes is assigned and is set to poer
  # I want to have the log transform on the y axis
  # But it's very arbitrary. I should have a way to clearly state it from the input to esquisse_server
  # However, it works for now :)
  if (!is.null(y_unit)) {
    scale_y_timeunit <- list("hours" = ggetho::scale_y_hours, "days" = ggetho::scale_y_days)[[y_unit]]
    if(!is.null(z_aes) && z_aes == "power") {
      y_log_transform <- TRUE
    } else {
      y_log_transform <- F
    }
    scale_y <- expr(scale_y_timeunit(log=y_log_transform))
    rlang::env_poke(env = parent.frame(), nm = "scale_y_timeunit", scale_y_timeunit)
    rlang::env_poke(env = parent.frame(), nm = "y_log_transform", y_log_transform)
    ggcall <- expr(!!ggcall + !!scale_y)
  }
  
  if (!is.null(z_aes)) {
    z_expr <- expr(ggplot2::aes_string(z = z_aes))
    rlang::env_poke(env = parent.frame(), nm = "z_aes", z_aes)
    ggcall <- expr(!!ggcall + !!z_expr)
    print(ggcall)
  }
  return(ggcall)
}

syms2 <- function(x) {
  lapply(
    X = x,
    FUN = function(y) {
      if (inherits(y, "AsIs")) {
        as.character(y)
      } else {
        sym(as_name(y))
      }
    }
  )
}

