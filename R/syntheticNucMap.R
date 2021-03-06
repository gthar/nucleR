#' Generates a synthetic nucleosome map
#'
#' This function generates a synthetic nucleosome map using the parameters
#' given by the user and returns the coverage (like NGS experiments) or a
#' pseudo-hybdridization ratio (like Tiling Arrays) toghether with the perfect
#' information about the well positioned and fuzzy nucleosome positions.
#'
#' @param wp.num Number of well-positioned (non overlapped) nucleosomes. They
#'   are placed uniformly every `nuc.len+lin.len` basepairs.
#' @param wp.del Number of well-positioned nucleosomes (the ones generated by
#'   `wp.num`) to remove. This will create an uncovered region.
#' @param wp.var Maximum variance in basepairs of the well-positioned
#'   nucleosomes. This will create some variation in the position of the reads
#'   describing the same nucleosome.
#' @param fuz.num Number of fuzzy nucleosomes. They are distributed randomly
#'   over all the region. They could be overlapped with other well-positioned
#'   or fuzzy nucleosomes.
#' @param fuz.var Maximum variance of the fuzzy nucleosomes. This allow to set
#'   different variance in well-positioned and fuzzy nucleosome reads (using
#'   `wp.var` and `fuz.var`).
#' @param max.cover Maximum coverage of a nucleosome, i.e., how many times a
#'   nucleosome read can be repeated. The final coverage probably will be
#'   higher by the addition of overlapping nucleosomes.
#' @param nuc.len Nucleosome length. It's not recomended change the default
#'   147bp value.
#' @param lin.len Linker DNA length. Usually around 20 bp.
#' @param rnd.seed As this model uses random distributions for the placement,
#'   by setting the rnd.seed to a known value allows to reproduce maps in
#'   different executions or computers. If you don't need this, just left it in
#'   default value.
#' @param as.ratio If `as.ratio=TRUE` this will create and return a synthetic
#'   naked DNA control map and the ratio between it and the nucleosome
#'   coverage. This can be used to simulate hybridization ratio data, like the
#'   one in Tiling Arrays.
#' @param show.plot If `TRUE`, will plot the output coverage map, with the
#'   nucleosome calls and optionally the calculated ratio.
#'
#' @return A list with the following elements:
#'   * wp.starts Start points of well-positioned nucleosomes
#'   * wp.nreads Number of repetitions of each well positioned read
#'   * wp.reads Well positioned nucleosome reads (`IRanges` format),
#'     containing the repetitions
#'   * fuz.starts Start points of the fuzzy nucleosomes
#'   * fuz.nreads Number of repetitions of each fuzzy nucleosome read
#'   * fuz.reads Fuzzy nucleosome reads (`IRanges` format), containing all
#'     the repetitions
#'   * syn.reads All synthetic nucleosome reads togheter (`IRanges` format)
#'
#'   The following elements will be only returned if `as.ratio=TRUE`:
#'   * ctr.reads The pseudo-naked DNA (control) reads (`IRanges` format)
#'   * syn.ratio The calculated ratio nucleosomal/control (`Rle` format)
#'
#' @author Oscar Flores \email{oflores@@mmb.pcb.ub.es}
#' @keywords datagen
#'
#' @examples
#' # Generate a synthetic map with 50wp + 20fuzzy nucleosomes using fixed
#' # random seed=1
#' res <- syntheticNucMap(wp.num=50, fuz.num=20, show.plot=TRUE, rnd.seed=1)
#' 
#' # Increase the fuzzyness
#' res <- syntheticNucMap(
#'     wp.num=50, fuz.num=20, wp.var=70, fuz.var=150, show.plot=TRUE,
#'     rnd.seed=1
#' )
#'
#' # Calculate also a random map and get the ratio between random and
#' # nucleosomal
#' res <- syntheticNucMap(
#'     wp.num=50, wp.del=0, fuz.num=20, as.ratio=TRUE, show.plot=TRUE,
#'     rnd.seed=1
#' )
#'
#' print(res)
#'
#' # Different reads can be accessed separately from results
#' # Let's use this to plot the nucleosomal + the random map
#' library(ggplot2)
#' as <- as.vector(coverage.rpm(res$syn.reads))
#' bs <- as.vector(coverage.rpm(res$ctr.reads))
#' cs <- as.vector(res$syn.ratio)
#' plot_data <- rbind(
#'     data.frame(x=seq_along(as), y=as, lab="nucleosomal"),
#'     data.frame(x=seq_along(bs), y=bs, lab="random"),
#'     data.frame(x=seq_along(cs), y=cs, lab="ratio")
#' )
#' qplot(x=x, y=y, data=plot_data, geom="area", xlab="position", ylab="") +
#'     facet_grid(lab~., scales="free_y")
#'
#' @export syntheticNucMap
#'
#' @importFrom IRanges IRanges
#' @importFrom stats runif
#' @importMethodsFrom BiocGenerics start
#' @importMethodsFrom IRanges coverage
#'
syntheticNucMap <- function (wp.num=100, wp.del=10, wp.var=20, fuz.num=50,
                             fuz.var=50, max.cover=20, nuc.len=147, lin.len=20,
                             rnd.seed=NULL, as.ratio=FALSE, show.plot=FALSE)
{
    # Set random seed if given
    if (!is.null(rnd.seed)) {
        set.seed(rnd.seed)
    }

    # WELL POS NUCLEOSOMES
    # Starting point of putative nucleosomes
    wp.starts <- (nuc.len + lin.len) * seq(0, wp.num - 1) + 1

    # How many times a read is repeated
    wp.nreads <- round(runif(wp.num, min=1, max=max.cover))

    # Delete some reads (set repetition times to 0)
    wp.nreads[round(runif(wp.del, min=0, max=wp.num))] <- 0

    # Set each nucleosome as a repeated single start position
    wp.repstar <- rep(wp.starts, wp.nreads)

    # Add some variance to the starting points
    var <- round(runif(length(wp.repstar), min=-wp.var, max=wp.var))
    wp.varstar <- wp.repstar + var

    # Putative reads
    wp.reads <- IRanges(start=wp.varstar, width=nuc.len)

    # OVERLAPPED (FUZZY) NUCLEOSOMES
    # Starting point of fuzzy nucleosomes (random)
    fuz.starts <- round(runif(
        fuz.num,
        min=1,
        max=(nuc.len + lin.len) * wp.num
    ))

    # How many times a read is repeated
    fuz.nreads <- round(runif(fuz.num, min=1, max=max.cover))

    # Set each nucleosome as a repeated single start position
    fuz.repstar <- rep(fuz.starts, fuz.nreads)

    # Add some variance to the starting points
    var <- round(runif(length(fuz.repstar), min=-fuz.var, max=fuz.var))
    fuz.varstar <- fuz.repstar + var

    # Overlapped reads
    fuz.reads <- IRanges(start=fuz.varstar, width=nuc.len)

    # ALL SYNTHETIC READS
    syn.reads <- c(wp.reads, fuz.reads)

    # RATIO AS HYBRIDIZATION (Tiling Array)
    if (as.ratio) {
        # Just put the same amount of reads as before randomly
        ctr.starts <- round(runif(
            length(syn.reads),
            min=1,
            max=max(start(syn.reads))
        ))

        # This time use a random read length, between 50 and 250 
        ctr.widths <- round(runif(length(syn.reads), min=50, max=250))

        # "Control reads"
        ctr.reads <- IRanges(start=ctr.starts, width=ctr.widths)

        # ratio
        syn.ratio <- suppressWarnings(
            log2(as.vector(coverage(syn.reads))) -
            log2(as.vector(coverage(ctr.reads)))
        )

        # Some lost bases... as reality
        syn.ratio[abs(syn.ratio) == Inf] <- NA
    } else {
        syn.ratio <- NULL
    }

    result <- list()

    result[["wp.starts"]] <- wp.starts
    result[["wp.nreads"]] <- wp.nreads
    result[["wp.reads"]] <- wp.reads

    result[["fuz.starts"]] <- fuz.starts
    result[["fuz.nreads"]] <- fuz.nreads
    result[["fuz.reads"]] <- fuz.reads

    result[["syn.reads"]] <- syn.reads

    if (as.ratio) {
        result[["ctr.reads"]] <- ctr.reads
        result[["syn.ratio"]] <- syn.ratio
    }

    if (show.plot) {
        print(.synthPlot(
            syn.reads,
            wp.starts,
            wp.nreads,
            fuz.starts,
            fuz.nreads,
            syn.ratio=syn.ratio
        ))
    }

    return (result)
}

.synthPlot <- function (..., syn.ratio=NULL)
{
    if (is.null(syn.ratio)) {
        .synthPlotNoRatio(...)
    } else {
        .synthPlotRatio(..., syn.ratio)
    }
}

#' @importFrom ggplot2 ggplot geom_area geom_point scale_fill_manual
#'   scale_color_manual theme xlab ylab aes element_blank
.synthPlotNoRatio <- function (syn.reads, wp.starts, wp.nreads, fuz.starts,
                               fuz.nreads)
{
    cov <- as.vector(coverage(syn.reads))
    covdf <- data.frame(y=cov, x=seq_along(cov), fill="coverage")
    nucdf <- rbind(data.frame(x=wp.starts+74, y=wp.nreads, type="well-pos"),
                   data.frame(x=fuz.starts+74, y=fuz.nreads, type="fuzzy"))
    ggplot() +
        geom_area(data=covdf,
                  mapping=aes(x=x, y=y, fill=fill)) +
        geom_point(data=nucdf,
                   mapping=aes(x=x, y=y, color=type)) +
        scale_fill_manual(values=c(coverage="#AADDAA")) +
        scale_color_manual(values=c("well-pos"="red", "fuzzy"="blue")) +
        theme(legend.title=element_blank()) +
        xlab("position") +
        ylab("number of reads")
}
globalVariables(c("x", "y", "fill", "type"))

#' @importFrom ggplot2 ggplot geom_area geom_point xlab ylab scale_fill_manual
#'   scale_color_manual facet_grid theme aes element_blank as_labeller
.synthPlotRatio <- function (syn.reads, wp.starts, wp.nreads, fuz.starts,
                             fuz.nreads, syn.ratio)
{
    cov <- as.vector(coverage(syn.reads))
    covdf <- data.frame(x=seq_along(cov), y=cov, facet="coverage")
    ratiodf <- data.frame(x=seq_along(syn.ratio), y=syn.ratio, facet="ratio")
    df <- rbind(covdf, ratiodf)

    nucdf <- rbind(data.frame(x=wp.starts+74, y=wp.nreads, type="well-pos"),
                   data.frame(x=fuz.starts+74, y=fuz.nreads, type="fuzzy"))
    nucdf$facet <- "coverage"
    syn.ratio[is.na(syn.ratio)] <- 0

    ggplot() +
        geom_area(data    = df,
                  mapping = aes(x=x, y=y, fill=facet)) +
        geom_point(data    = nucdf,
                   mapping = aes(x=x, y=y, color=type)) +
        xlab("position") +
        ylab(NULL) +
        scale_fill_manual(values=c("coverage" = "#AADDAA",
                                   "ratio"    = "darkorange")) +
        scale_color_manual(values=c("well-pos" = "red",
                                    "fuzzy"    = "blue")) +
        facet_grid(facet~.,
                   switch="both",
                   scales = "free_y", space = "free_y",
                   labeller       = as_labeller(c(coverage = "number of reads",
                                                  ratio    = "log2 ratio"))) +
        theme(strip.placement  = "outside",
              legend.title     = element_blank(),
              strip.background = element_blank())
}
globalVariables(c("x", "y", "facet", "tyoe"))
