#' Get optimal number of components
#'
#' Compute the average silhouette coefficient for a given set of components on a mixOmics result.
#' Foreach given ncomp, the mixOmics method is performed with the sames arguments and the given `ncomp`.
#' Longitudinal clustering is performed and average silhouette coefficient is computed.
#'
#' @param object A mixOmics object of the class `pca`, `spca`, `mixo_pls`, `mixo_spls`, `block.pls`, `block.spls`
#'
#' @param max.ncomp integer, maximum number of component to include.
#' If no argument is given, `max.ncomp=object$ncomp`
#' 
#' @param X a numeric matrix/data.frame or a list of data.frame for \code{block.pls}
#' 
#' @param Y (only for \code{pls}, optional for \code{block.spls}) a numeric matrix, with the same nrow as \code{X}
#' 
#' @param indY (optional and only for \code{block.pls}, if Y is not provided), an integer which indicates the position of the matrix response in the list X
#' 
#' @param ... Other arguments to be passed to methods (pca, pls, block.pls)
#' 
#' @return
#' \code{getNcomp} returns a list with class "ncomp.tune.silhouette" containing the following components:
#'
#' \item{ncomp}{a vector containing the tested ncomp}
#' \item{silhouette}{a vector containing the average silhouette coefficient by ncomp}
#' \item{dmatrix}{the distance matrix used to compute silhouette coefficient}
#'
#' @seealso 
#' \code{\link{getCluster}}, \code{\link{silhouette}}, \code{\link[mixOmics]{pca}}, \code{\link[mixOmics]{pls}}, \code{\link[mixOmics]{block.pls}}
#'
#' @examples
#' # random input data
#' demo <- suppressWarnings(get_demo_cluster())
#'
#' # pca
#' pca.res <- mixOmics::pca(X=demo$X, ncomp = 5)
#' res.ncomp <- getNcomp(pca.res, max.ncomp = 4, X = demo$X)
#' plot(res.ncomp)
#' 
#' # pls
#' pls.res <- mixOmics::pls(X=demo$X, Y=demo$Y)
#' res.ncomp <- getNcomp(pls.res, max.ncomp = 4, X = demo$X, Y=demo$Y)
#' plot(res.ncomp)
#' 
#' # block.pls
#' block.pls.res <- suppressWarnings(mixOmics::block.pls(X=list(X=demo$X, Z=demo$Z), Y=demo$Y))
#' res.ncomp <- suppressWarnings(getNcomp(block.pls.res, max.ncomp = 4,
#'                                        X=list(X=demo$X, Z=demo$Z), Y=demo$Y))
#' plot(res.ncomp)
#'
#' @export
#' @import mixOmics
getNcomp <- function(object, max.ncomp = NULL, X, Y = NULL, indY = NULL, ...){
    #-- checking input parameters ---------------------------------------------#
    #--------------------------------------------------------------------------#

    #-- object
    allowed_object = c("pca", "mixo_pls", "block.pls")
    if(!any(class(object) %in% allowed_object)){
        stop("invalid object, should be one of c(pca, mixo_pls, block.pls)")
    }
    

    #-- max.ncomp
    if(is_almostInteger(max.ncomp)){
        if (max.ncomp < 1)
            stop("'max.ncomp' should be greater than 1")

        if(is(object, "block.pls")){
            if (max.ncomp > min(ncol(object$X[[1]]), nrow(object$X[[1]])))
                stop("use smaller 'max.ncomp'")   
        } else {
            if (max.ncomp > min(ncol(object$X), nrow(object$X)))
                stop("use smaller 'max.ncomp'")
        }
    } else {
        max.ncomp <- unique(object$ncomp)
    }

    #-- run  #pca / pls / block.pls
    ncomp.opt.res <- ncomp.silhouette(object, X, Y, max.ncomp, indY, ...)
    
    to_return <- list()
    to_return[["ncomp"]] <- c(0,1:max.ncomp)
    to_return[["silhouette"]] <- c(0,ncomp.opt.res$silhouette.res)
    to_return[["dmatrix"]] <- ncomp.opt.res$dmatrix
    to_return[["choice.ncomp"]] <- to_return[["ncomp"]][which.max(to_return[["silhouette"]])]

    class(to_return) <- "ncomp.tune.silhouette"
    return(invisible(to_return))
}

ncomp.silhouette <- function(object, X = X, max.ncomp = max.ncomp, ...){
    UseMethod("ncomp.silhouette")
}

#' @import mixOmics
ncomp.silhouette.pca <- function(object, X, Y, max.ncomp, indY, ...){
    #-- check X
    X <- validate_matrix_X(X)
    
    #-- dmatrix
    dmatrix <- dmatrix.spearman.dissimilarity(X)
    
    silhouette.res <- vector(length = max.ncomp)
    #-- iterative ncomp silhouette coef.
    for(comp in 1:max.ncomp){
        #-- mixo pca
        mixo.res <- mixOmics::pca(X = X, ncomp = comp, ...)
        
        #-- cluster
        cluster.res <- getCluster(X = mixo.res)
        # same names, same cluster
        stopifnot(all(cluster.res$molecule == colnames(dmatrix))) 
        
        #-- silhouette
        sil <- silhouette(dmatrix, cluster.res$cluster)
        
        #-- store
        silhouette.res[comp] <- sil$average
    }
    
    return(list(silhouette.res = silhouette.res, dmatrix = dmatrix))
}

#' @import mixOmics
ncomp.silhouette.mixo_pls <- function(object, X, Y, max.ncomp, indY, ...){
    #-- check X
    X <- validate_matrix_X(X)
    
    #-- check Y
    Y <- validate_matrix_Y(Y)
    
    #-- dmatrix
    dmatrix <- dmatrix.spearman.dissimilarity(cbind(X,Y))
    
    silhouette.res <- vector(length = max.ncomp)
    #-- iterative ncomp silhouette coef.
    for(comp in 1:max.ncomp){
        #-- mixo pls
        mixo.res <- mixOmics::pls(X = X, Y=Y, ncomp = comp, ...)
        
        #-- cluster
        cluster.res <- getCluster(X = mixo.res)
        # same names, same cluster
        stopifnot(all(cluster.res$molecule == colnames(dmatrix))) 
        
        #-- silhouette
        sil <- silhouette(dmatrix, cluster.res$cluster)
        
        #-- store
        silhouette.res[comp] <- sil$average
    }
    return(list(silhouette.res = silhouette.res, dmatrix = dmatrix))
}

#' @import mixOmics
ncomp.silhouette.block.pls <- function(object, X, Y, max.ncomp, indY, ...){
    #-- check X
    X <- validate_list_matrix_X(X)
    
    data <- do.call("cbind", X)
    
    #-- Y
    if(!is.null(Y)){
        Y <- validate_matrix_Y(Y)
        dmatrix <- dmatrix.spearman.dissimilarity(cbind(data,Y))
        indY <- NULL
    } else {
        indY <- validate_indY(indY = indY, X=X)
        dmatrix <- dmatrix.spearman.dissimilarity(data)
    }
    
    silhouette.res <- vector(length = max.ncomp)
    #-- iterative ncomp silhouette coef.
    for(comp in 1:max.ncomp){
        #-- mixo block.pls
        if(is.null(indY)){
            mixo.res <- mixOmics::block.pls(X = X, ncomp = comp, Y = Y, ...)
        }else{
            mixo.res <- mixOmics::block.pls(X = X, ncomp = comp, indY = indY, ...)
        }
        
        #-- cluster
        cluster.res <- getCluster(X = mixo.res)
        # same names, same cluster
        stopifnot(all(cluster.res$molecule == colnames(dmatrix))) 
        
        #-- silhouette
        sil <- silhouette(dmatrix, cluster.res$cluster)
        
        #-- store
        silhouette.res[comp] <- sil$average
    }
    return(list(silhouette.res = silhouette.res, dmatrix = dmatrix))
}

#' @export
#' @import ggplot2
plot.ncomp.tune.silhouette <- function(x, title = NULL, ...){
    stopifnot(is(x, "ncomp.tune.silhouette"))
    
    # check title
    if(!is.character(title)){title = NULL}

    data <- as.data.frame(list(ncomp = x$ncomp, silhouette = x$silhouette))
    ggplot_df <- ggplot2::ggplot(data, aes(x=ncomp, y = silhouette)) + geom_line() + geom_point() +
        geom_vline(xintercept = x$choice.ncomp, lty=2, col = "grey") +
        theme_bw() +
        xlab("Number of Principal Components") + 
        ylab("Average Silhouette Coefficient")
    
    # add title
    if(is.character(title)){
        ggplot_df <- ggplot_df + ggtitle(title)
    }
    print(ggplot_df)
    return(invisible(ggplot_df))
}
