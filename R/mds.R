#' (Dis)similarity based brand maps (MDS)
#'
#' @details See \url{http://vnijs.github.io/radiant/marketing/mds.html} for an example in Radiant
#'
#' @param dataset Dataset name (string). This can be a dataframe in the global environment or an element in an r_data list from Radiant
#' @param id1 A character variable or factor with unique entries
#' @param id2 A character variable or factor with unique entries
#' @param dis A numeric measure of brand dissimilarity
#' @param method Apply metric or non-metric MDS
#' @param nr_dim Number of dimensions
#' @param data_filter Expression entered in, e.g., Data > View to filter the dataset in Radiant. The expression should be a string (e.g., "price > 10000")
#'
#' @return A list of all variables defined in the function as an object of class mds
#'
#' @examples
#' result <- mds("city", "from", "to", "distance")
#' summary(result)
#' result <- mds("diamonds", "clarity", "cut", "price")
#' summary(result)
#'
#' @seealso \code{\link{summary.mds}} to summarize results
#' @seealso \code{\link{plot.mds}} to plot results
#'
#' @importFrom MASS isoMDS
#'
#' @export
mds <- function(dataset, id1, id2, dis,
                method = "metric",
                nr_dim = 2,
                data_filter = "") {


	nr_dim <- as.numeric(nr_dim)
	dat <- getdata(dataset, c(id1, id2, dis), filt = data_filter)
	if (!is_string(dataset)) dataset <- "-----"

	d <- dat[,dis]
	id1_dat <- dat[ ,id1] %>% as.character
	id2_dat <- dat[ ,id2] %>% as.character
	rm(dat)

	## ids
	lab <- unique(c(id1_dat, id2_dat))
	nrLev <- length(lab)

	lower <- (nrLev * (nrLev - 1)) / 2
	nrObs <- length(d)

	## setup the distance matrix
	mds_dis_mat <- diag(nrLev)
	if (lower == nrObs) {
		mds_dis_mat[lower.tri(mds_dis_mat, diag = FALSE)] <- d
	} else if ((lower + nrLev) == nrObs) {
		mds_dis_mat[lower.tri(mds_dis_mat, diag = TRUE)] <- d
	} else {
		return("Number of observations and unique IDs for the brand variable do not match.\nPlease choose another brand variable or another dataset.\n\nFor an example dataset go to Data > Manage, select 'examples' from the\n'Load data of type' dropdown, and press the 'Load examples' button. Then\nselect the \'city' dataset." %>% set_class(c("mds",class(.))))
	}

	mds_dis_mat %<>% set_rownames(lab) %>%
		set_colnames(lab) %>%
		as.dist

	## Alternative method, metaMDS - requires vegan
	# res <- suppressWarnings(metaMDS(mds_dis_mat, k = nr_dim, trymax = 500))
	# if (res$converged == FALSE) return("The MDS algorithm did not converge. Please try again.")

	set.seed(1234)
	res <- MASS::isoMDS(mds_dis_mat, k = nr_dim, trace = FALSE)
	res$stress <- res$stress / 100

	if (method == "metric") {
		res$points <- cmdscale(mds_dis_mat, k = nr_dim)
		## Using R^2
		# res$stress <- sqrt(1 - cor(dist(res$points),mds_dis_mat)^2) * 100
		# Using standard Kruskal formula for metric MDS
		res$stress	<- { sum((dist(res$points) - mds_dis_mat)^2) / sum(mds_dis_mat^2) } %>%
											 sqrt
	}

	environment() %>% as.list %>% set_class(c("mds",class(.)))
}

#' Summary method for the mds function
#'
#' @details See \url{http://vnijs.github.io/radiant/marketing/mds.html} for an example in Radiant
#'
#' @param object Return value from \code{\link{mds}}
#' @param dec Rounding to use for output (default = 0). +1 used for coordinates. +2 used for stress measure. Not currently accessible in Radiant
#' @param ... further arguments passed to or from other methods
#'
#' @examples
#' result <- mds("city", "from", "to", "distance")
#' summary(result)
#' summary(result, dec = 2)
#' city %>% mds("from", "to", "distance") %>% summary
#'
#' @seealso \code{\link{mds}} to calculate results
#' @seealso \code{\link{plot.mds}} to plot results
#'
#' @export
summary.mds <- function(object, dec = 1, ...) {

	if (is.character(object)) return(cat(object))

	cat("(Dis)similarity based brand map (MDS)\n")
	cat("Data        :", object$dataset, "\n")
	if (object$data_filter %>% gsub("\\s","",.) != "")
		cat("Filter      :", gsub("\\n","", object$data_filter), "\n")
	cat("Variables   :", paste0(c(object$id1, object$id2, object$dis), collapse = ", "), "\n")
	cat("# dimensions:", object$nr_dim, "\n")
	meth <- if (object$method == "non-metric") "Non-metric" else "Metric"
	cat("Method      :", meth, "\n")
	cat("Observations:", object$nrObs, "\n")

	cat("\nOriginal distance data:\n")
	object$mds_dis_mat %>% round(dec) %>% print

	cat("\nRecovered distance data:\n")
	object$res$points %>% dist %>% round(dec) %>% print

	cat("\nCoordinates:\n")
	object$res$points %>% round(dec + 1) %>%
	 set_colnames({paste("Dim ", 1:ncol(.))}) %>%
	 print

	cat("\nStress:", object$res$stress %>% round(dec + 2))
}

#' Plot method for the mds function
#'
#' @details See \url{http://vnijs.github.io/radiant/marketing/mds.html} for an example in Radiant
#'
#' @param x Return value from \code{\link{mds}}
#' @param rev_dim Flip the axes in plots
#' @param fontsz Font size to use in plots
#' @param ... further arguments passed to or from other methods
#'
#' @examples
#' result <- mds("city","from","to","distance")
#' plot(result)
#' plot(result, rev_dim = 1:2)
#' plot(result, rev_dim = 1:2, fontsz = 2)
#'
#' @seealso \code{\link{mds}} to calculate results
#' @seealso \code{\link{summary.mds}} to plot results
#'
#' @importFrom wordcloud textplot
#'
#' @export
plot.mds <- function(x,
                     rev_dim = "",
                     fontsz = 1.3,
                     ...) {

	object <- x; rm(x)

	## set extremes for plot
	lim <- max(abs(object$res$points))

	## set plot space
	if (object$nr_dim == 3) {
		op <- par(mfrow = c(3, 1))
		fontsz <- fontsz + .6
	} else {
		op <- par(mfrow = c(1, 1))
	}

	## reverse selected dimensions
	if (!is.null(rev_dim) && rev_dim != "") {
		as.numeric(rev_dim) %>%
			{ object$res$points[,.] <<- -1 * object$res$points[,.] }
	}

	## plot maps
	for (i in 1:(object$nr_dim - 1)) {
		for (j in (i + 1):object$nr_dim) {
			plot(c(-lim, lim), type = "n", xlab= "", ylab = "", axes = FALSE, asp = 1,
			     yaxt = "n", xaxt = "n", ylim = c(-lim, lim), xlim = c(-lim, lim))
			title(paste("Dimension", i, "vs Dimension", j), cex.main = fontsz)
			points(object$res$points[ ,i], object$res$points[ ,j], pch = 16, cex = .6)
			wordcloud::textplot(object$res$points[ ,i], object$res$points[ ,j] +
			                    (.04 * lim), object$lab, col = rainbow(object$nrLev, start = .6, end = .1),
			                    cex = fontsz, new = FALSE)
			abline(v = 0, h = 0)
		}
	}
	par(op)
}
