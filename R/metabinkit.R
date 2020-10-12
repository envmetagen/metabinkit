# =========================================================
# Copyright 2020
#
#
# This is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# if not, see <http://www.gnu.org/licenses/>.
#
#
# =========================================================

metabinkit.version <- "0.1.8"

## Ensure that we are using a recent version of R
##
R.version <- getRversion()
currentVersion <- sprintf("%d.%d", R.version$major, R.version$minor)
if ( getRversion() < "3.6.0"  ) {
    message("R version:",currentVersion)
    cat("ERROR: R version should be 3.6 or above\n")
    q(status=1)
}

####################
## should be defined
if ( is.null(mbk.local.lib.path) ) {
    mbk.local.lib.path <- "."
}
source(paste0(mbk.local.lib.path,"/lca.R"))

print.version <- function() {
    message("metabinkit version: ",metabinkit.version)
}

## re: regular expression/pattern
## df: dataframe
## ...
grep.filter <- function(re,df,lookup.column="S",invert=FALSE,...) {
    res <- list(df=NULL,nremoved=0)
    count.bef <- nrow(df)
    toremove <- -grep(re,df[,lookup.column],ignore.case = TRUE,invert=invert,...)
    if (length(toremove)>0)
        df<-df[toremove,,drop=FALSE]
    count.aft <- nrow(df)
    res$nremoved <- count.bef-count.aft
    ## it should be == length(toremove) ;-)
    res$df <- df
    return(res)
}
set_within_limit <- function(v,min,max) {
    return(min(max(v,min),max))
}


##
## Binning
##
metabin <- function(ifile,
                    taxDir,
                    spident=98,
                    gpident=95,
                    fpident=92,
                    abspident=80,
                    topS=1,
                    topG=1,
                    topF=1,
                    topAbs=1, #
                    no_mbk=FALSE,
                    species.blacklist=NULL,
                    genus.blacklist=NULL,
                    family.blacklist=NULL,
                    #disabledTaxaFiles=NULL,
                    disabledTaxaOut=NULL, ## file prefix
                    ## force=F, ## ??
                    ## full.force=F, ##??
                    filter.col=NULL,
                    filter=NULL,
                    species.neg=NULL,
                    rm.predicted=NULL,
                    sp.consider.sp=FALSE,
                    sp.consider.numbers=FALSE,
                    sp.consider.mt2w=FALSE,
                    quiet=FALSE) {
    
    ####################
    ## validate arguments
    if(is.null(taxDir)) perror(fatal=TRUE,"taxDir not specified");
    if(!file.exists(ifile)) perror(fatal=TRUE,"file ", ifile, " not found"); 

    ## all arguments look ok, carry on...
    library(data.table)
    options(datatable.fread.input.cmd.message=FALSE)

    topS <- set_within_limit(topS,0,100)
    topG <- set_within_limit(topG,0,100)
    topF <- set_within_limit(topF,0,100)
    topAbs <- set_within_limit(topAbs,0,100)
    ## start timer
    t1<-Sys.time()
    
    ## would prefer that file was loader prior to this function being called
    ## lets keep it for now
    btab.o<-data.table::fread(ifile,sep="\t",data.table = F)
    pinfo(verbose=!quiet,"Read ",nrow(btab.o)," entries from ",ifile)
    #if ( nrow(btab.o) == 0 ) {
    #    perror(fatal=TRUE,"Unable to proceed - no data")
    #}
    ## are the expected columns present?
    ## accept staxids instead of taxids
    if ( "staxids"%in%colnames(btab.o) && !"taxids"%in%colnames(btab.o)) {
        pinfo("taxids column not found, using staxids instead")
        btab.o$taxids <- btab.o$staxids
    } else {
      if ( "staxid"%in%colnames(btab.o) && !"taxids"%in%colnames(btab.o)) {
        pinfo("taxids column not found, using staxid instead")
        btab.o$taxids <- btab.o$staxid
      }
    }

    ## qseqid pident taxids
    expected.cols <- c("qseqid","pident","taxids")
    if(!is.null(filter.col) && !is.null(filter)) {
        expected.cols <- c(expected.cols,filter.col)
    }
    if(!is.null(rm.predicted)) {
        expected.cols <- c(expected.cols,rm.predicted)
    }
    not.found <- expected.cols[!expected.cols%in%colnames(btab.o)]
    if ( length(not.found) > 0 ) perror(fatal=TRUE,"missing columns in input table:",paste(not.found,collapse=","))

    ## Filter
    if(!is.null(filter.col) && !is.null(filter)) {
        pinfo("Filtering table (",nrow(btab.o),") using ",filter.col," column.")
        btab.o <- btab.o[!btab.o[,filter.col]%in%filter$V1,,drop=FALSE]
        pinfo("Filtered table (",nrow(btab.o),") using ",filter.col," column.")
    }
    
    ## check if lineage information is available
    expected.tax.cols <- c("K","P","C","O","F","G","S")
    not.found <- expected.tax.cols[!expected.tax.cols%in%colnames(btab.o)]
    if ( length(not.found) > 0 ) {
        message(" WARNING! missing columns in input table with taxonomic information:",paste(not.found,collapse=","))
        pinfo(" Trying to get taxonomic information from the database in ",taxDir," ...")
        ## 
        btab.o <- add.lineage.df(btab.o,taxDir=taxDir,taxCol="taxids")
        pinfo(" taxonomic information retrieval complete.")
        ## Double check that all cols are present
        not.found <- expected.tax.cols[!expected.tax.cols%in%colnames(btab.o)]
        if ( length(not.found) > 0 ) {
            perror(fatal=TRUE," Missing columns in input table with taxonomic information:",paste(not.found,collapse=","))
        }
        ## Missing taxids
        num.tnf.sp <- sum(btab.o$S=="mbk:tnf")
        num.tnf.g <- sum(btab.o$G=="mbk:tnf")
        num.tnf.f <- sum(btab.o$F=="mbk:tnf")
        if ( num.tnf.sp >0 || num.tnf.g>0 || num.tnf.g >0 ) {
            message("WARNING: Some taxids were not found in the taxonomy database, consider checking if they are correct and/or updating the taxonomy database. All taxids not found (tnf) are marked in the final table as mbk:tnf.")
        }
    }
    
    ## check NAs in taxonomy. Should only be an issue if user provided custom taxonomy
    ## This can happen when the blast database and taxonomy mapping file are merged, but have differences in qseqids/saccvers 
    countNAs<-sum(is.na(btab.o[,expected.tax.cols]))
    if(countNAs>0) {
      perror(countNAs," NAs found in taxonomy columns. Converting NAs to 'unknown', consider checking input taxonomy if this appears erroneous.")
      btab.o[,expected.tax.cols][is.na(btab.o[,expected.tax.cols])]<-"unknown"
    }
    
    ## keep only the necessary columns
    btab <- btab.o[,c(expected.cols,expected.tax.cols),drop=FALSE]   
    rm(btab.o)

    cols <- colnames(btab)
    ## add a numeric index column (spedup lookups)
    btab <- cbind(idx=as.integer(rownames(btab)),btab)
    ## min_pident (NA if not binned)
    if(nrow(btab)>0) {
        btab$min_pident <- NA
    } else {
        btab$min_pident <- btab$idx
    }
    ## reorder cols
    btab <- btab[,c("idx","min_pident",cols),drop=FALSE]

    ## record the numbers
    stats <- list()
    stats$total_hits <- nrow(btab)
    stats$total_queries<- length(unique(btab$qseqid))

    ##################################################################
    ## Blacklisting
    blacklists <- list(species.level=species.blacklist,
                  family.level=family.blacklist,
                  genus.level=genus.blacklist)
    #blacklists$family.level
    ##
    blacklists.children <- lapply(blacklists,get.taxids.children,taxonomy_data_dir=taxDir)

    ## some info...
    if (!is.null(blacklists$species.level)) pinfo(verbose=!quiet,"Maximum # Taxa disabled at species level:",length(blacklists.children$species.level))
    if (!is.null(blacklists$genus.level)) pinfo(verbose=!quiet,"Maximum # Taxa disabled at genus level:",length(blacklists.children$genus.level))
    if (!is.null(blacklists$family.level)) pinfo(verbose=!quiet,"Maximum # Taxa disabled at family level:",length(blacklists.children$family.level))


##################################################################
    stats$rm.predicted <- 0L
    if (!is.null(rm.predicted)) {
        pinfo(verbose=!quiet,"Not considering in-silico predicted sequences (XM_*,XR_*,XP_*)")
        rm.predicted.found <- grepl("\\s(XM|XR|XP)_.*",btab[,rm.predicted],perl=TRUE)
        stats$rm.predicted <- sum(rm.predicted.found)
        if (stats$rm.predicted>0) {
            btab<-btab[!rm.predicted.found,,drop=FALSE] 
        }
        pinfo(verbose=!quiet,"Removed ",stats$rm.predicted," entries")
    }
    ##################################################################
    ##species-level assignments
    pinfo(verbose=!quiet,"binning at species level")
    ## blacklists
    btab<-apply.blacklists(btab,blacklists.children,level="S",mark.bl="mbk:bl-S")
    
    ## multiple filters at species level
    stats$species.level.sp.filter <- 0L
    if(sp.consider.sp==FALSE){
        pinfo(verbose=!quiet,"Not considering species with 'sp.'")
        res <- grep.filter(" sp\\.",df=btab)
        btab <- res$df
        stats$species.level.sp.filter <- res$nremoved
    }
    
    stats$species.level.mt2w.filter <- 0L
    if(sp.consider.mt2w==FALSE){
        pinfo(verbose=!quiet,"Not considering species with more than two words")
        res <- grep.filter("[^\\s]+\\s+[^\\s]+\\s+[^\\s].*",df=btab,perl=TRUE,invert=FALSE)
        btab <- res$df
        stats$species.level.mt2w.filter <- res$nremoved
    }
    
    stats$species.level.numbers.filter <- 0L
    if(sp.consider.numbers==FALSE){
        pinfo(verbose=!quiet,"Not considering species with numbers")
        res <- grep.filter("\\d",df=btab,perl=TRUE,invert=FALSE)
        btab <- res$df
        stats$species.level.numbers.filter <- res$nremoved
        rm(res)
    }

    ## Negative Filter
    stats$species.neg.filter <- 0L
    if ( !is.null(species.neg) ) {
        pinfo(verbose=!quiet,"Not considering species with ",paste(species.neg,sep=","))
        for ( f in species.neg ) {
            res <- grep.filter(f,df=btab,perl=TRUE,invert=FALSE)
            btab <- res$df
            stats$species.neg.filter=res$nremoved+stats$species.neg.filter
        }
    }

    
    btab.sp<-btab[grep("(unknown|mbk:bl-)",btab$S,perl=TRUE,invert=TRUE),,drop=FALSE]
    bres <- binAtLevel(btab,btab.l=btab.sp,"S",min_pident=spident,top=topS,quiet=quiet,expected.tax.cols=expected.tax.cols)
    binned.sp <- bres$binned
    stats$binned.species.level <- bres$nbinned
    btab <- bres$btab

    rm(btab.sp)
    rm(bres)
    pinfo(verbose=!quiet,"binned ",stats$binned.species.level," sequences at species level")
    ##################################################################
    ##genus-level assignments
    pinfo(verbose=!quiet,"binning at genus level") 
    ##reason - can have g=unknown and s=known (e.g. Ranidae isolate), these should be removed
    ##can have g=unknown and s=unknown (e.g. Ranidae), these should be removed
    ##can have g=known and s=unknown (e.g. Leiopelma), these should be kept
    btab<-apply.blacklists(btab,blacklists.children,level="G",mark.bl="mbk:bl-G")    
    btab.g<-btab[grep("(unknown|mbk:bl-)",btab$G,perl=TRUE,invert=TRUE),,drop=FALSE]

    bres <- binAtLevel(btab,btab.l=btab.g,"G",min_pident=gpident,top=topG,quiet=quiet,expected.tax.cols=expected.tax.cols)
    binned.g <- bres$binned
    stats$binned.genus.level <- bres$nbinned
    btab <- bres$btab
    rm(btab.g)
    rm(bres)
    pinfo(verbose=!quiet,"binned ",stats$binned.genus.level," sequences at genus level")
    #################################################################
    ##family-level assignments
    pinfo(verbose=!quiet,"binning at family level")
    ##can have f=known, g=unknown, s=unknown, these should be kept
    ##can have f=unknown, g=known, s=known, these should be kept
    ##can have f=unknown, g=known, s=unknown, these should be kept
    ##can have f=known, g=known, s=unknown, these should be kept
    ##can have f=known, g=known, s=known, these should be kept
    ##can have f=unknown, g=known, s=unknown, these should be kept
    ##can have f=known, g=unknown, s=known, these should be kept    
    ##can have f=unknown, g=unknown, s=known, these should be removed - 
    ##assumes that this case would be a weird entry (e.g. Ranidae isolate)  
    ##can have f=unknown, g=unknown, s=unknown, these should be removed

    ## Bastian: not sure if the following conditions are correct
    btab<-apply.blacklists(btab,blacklists.children,level="F",mark.bl="mbk:bl-F")
    btab.f<-btab[grep("(unknown|mbk:bl-)",btab$F,perl=TRUE,invert=TRUE),,drop=FALSE]
    bres <- binAtLevel(btab,btab.l=btab.f,"F",min_pident=fpident,top=topF,quiet=quiet,expected.tax.cols=expected.tax.cols)
    binned.f <- bres$binned
    stats$binned.family.level <- bres$nbinned
    btab <- bres$btab
    rm(btab.f)
    rm(bres)
    pinfo(verbose=!quiet,"binned ",stats$binned.family.level," sequences at family level")
    ##################################################################
    ##higher-than-family-level assignments
    pinfo(verbose=!quiet,"binning at higher-than-family level")
    btab.htf<-btab[btab$K!="unknown",,drop=FALSE] 
    #think O makes more sense here, and is lca being reversed?
    bres <- binAtLevel(btab,btab.l=btab.htf,c("O","C","P","K"),min_pident=abspident,top=topAbs,quiet=quiet,expected.tax.cols=expected.tax.cols)
    binned.htf <- bres$binned
    stats$binned.htf.level <- bres$nbinned
    btab <- bres$btab
    
    rm(btab.htf)
    pinfo(verbose=!quiet,"binned ",stats$binned.htf.level," sequences at higher than family level")
    
    #######################################################################
    ##combine binned/assigned
    atab <- rbind(binned.sp,binned.g,binned.f,binned.htf)
    pinfo(verbose=!quiet,"Total number of binned ",nrow(atab)," sequences")

    ###################################################################
    ## unassigned/not binned
    ## remove the binned qseqid
    btab.u <- btab[!btab$qseqid%in%atab$qseqid,,drop=FALSE]
    ## use data.table
    if (nrow(btab.u)>0) {
        setDT(btab.u)
        btab.u <- btab.u[btab.u[, .I[pident==max(pident)], by=qseqid]$V1]
        ## discard ties
        btab.u <- btab.u[!duplicated(btab.u$qseqid),,drop=FALSE]
        btab.u <- as.data.frame(btab.u)
    }
    
    if (nrow(btab.u)==0) {
        ##btab.u[,expected.tax.cols] <- "unknown"
        ##btab.u$min_pident <- NA
    ##} else {
        ## empty matrix
        d<-data.frame(matrix(nrow=0,ncol=1))
        colnames(d) <- c("min_pident")
        btab.u <- cbind(btab.u,d)
    } else {
        ## remove the extra column
        btab.u <- btab.u[,!colnames(btab.u)%in%c("taxids"),drop=FALSE]
    }
        
    
    stats$not.binned <- nrow(btab.u)
    pinfo(verbose=!quiet,"not binned ",stats$not.binned," sequences")

    
    ftab <- rbind(atab,btab.u[,colnames(atab),drop=FALSE])
    ## Hide explanation (backwards compatibility)
    if (no_mbk==TRUE) {
        for ( c in expected.tax.cols ) {
            ftab[grep("mbk:",x=ftab[,c],fixed=TRUE),c] <- NA
        }
    }

    ## empty output
    if (nrow(ftab)==0) {
        ftab <- btab
        ## reorder columns
        ftab <- ftab[,c(expected.cols,"min_pident",expected.tax.cols),drop=FALSE]
    } else {
        ## remove the idx column
        ftab <- ftab[,-grep("idx",colnames(ftab)),drop=FALSE]
    }
    
    ############################################################
    ## Wrapping up
    t2<-Sys.time()
    t3<-round(difftime(t2,t1,units = "mins"),digits = 2)

    #write.table(x = com_level,file = out,sep="\t",quote = F,row.names = F)
  
    pinfo(verbose=!quiet,"Complete. ",stats$total_hits, " hits from ", stats$total_queries," queries processed in ",t3," mins.")
    
    pinfo(verbose=!quiet,"
Note: By default, if a taxon cannot be assigned at a given taxonomic level the following codes are used to explain the motive:
- mbk:bl-S,mbk:bl-G,mbk:bl-F - taxid blacklisted at species, genus or family (respectively)
- mbk:nb-thr - pident was below the threshold
- mbk:nb-lca - the lowest common ancestor was above this taxonomic level
- mbk:tnf - the taxid was not found in the taxonomy database
If --no_mbk option was used the codes will be NA
")
    res <- list(table=ftab,stats=stats)
    return(res)
}


binAtLevel <- function(btab,btab.l,level,min_pident,top,expected.tax.cols,quiet=FALSE) {
    binned.l <- NULL
    nbinned <- NULL
    if ( nrow(btab.l) > 0 ) {
        above.threshold <- btab.l$pident>=min_pident
        pinfo(verbose=!quiet,"excluding ",sum(!above.threshold)," entries with pident below ",min_pident)
        not.passing.ids <- btab.l$idx[!above.threshold]
        btab.l<-btab.l[above.threshold,,drop=FALSE]
        btab[as.character(not.passing.ids),level] <- "mbk:nb-thr"
        ## keep all ids
        ids <- btab.l$idx
        ## get top
        pinfo(verbose=!quiet,"applying top threshold of ",top)
        btab.l<- get.top(btab.l,topN=top)
        ## LCA
        lca.l <- get.lowest.common.ancestor(btab.l)
        binned.l <- get.binned(btab.l,lca.l,level,expected.tax.cols)
        ## remove binned entries
        btab <- btab[!btab$qseqid%in%binned.l$qseqid,,drop=FALSE]
        ## mark remaining entries
        btab[btab$idx%in%as.character(ids),level] <- "mbk:nb-lca"
        nbinned <- nrow(binned.l)
        rm(lca.l)
    }
    if (is.null(nbinned)) nbinned <- 0L
    return(list(btab=btab,binned=binned.l,nbinned=nbinned))
}

get.binned <- function(tab,lca,taxlevel,taxcols=c("K","P","C","O","F","G","S")) {
    get.binned.ids <- function(lca,taxlevel) {
        return(lca[lca[,taxlevel]!="mbk:nb-lca","qseqid"])
    }
    binned.ids <- c()
    ##if (nrow(lca)>0) 
    binned.ids <- unique(unlist(lapply(taxlevel,FUN=get.binned.ids,lca=lca)))  
    binned <- tab[tab$qseqid%in%binned.ids,c("idx","qseqid","pident","min_pident"),drop=FALSE]
    binned <- binned[!duplicated(binned$qseqid),,drop=FALSE]
    binned <- cbind(binned,lca[match(binned$qseqid,lca$qseqid),taxcols,drop=FALSE])
    nb <- tab$idx[tab$idx%in%binned$idx]
    return(binned)
    #idx <- max(which(colnames(binned) %in% taxlevel))+1
    #if ( idx < length(colnames(binned)) && nrow(binned)>0) {
        ## all levels below the one where the binning has occured are set to NA
        ## do nothing when taxlevel=S        
        #binned[,seq(idx,length(colnames(binned)))] <- NA
}

get.binned0 <- function(tab,lca,taxlevel,taxcols=c("K","P","C","O","F","G","S")) {
    get.binned.ids <- function(lca,taxlevel) {
        return(lca[lca[,taxlevel]!="unknown","qseqid"])
    }
    binned.ids <- c()
    ##if (nrow(lca)>0) 
    binned.ids <- unique(unlist(lapply(taxlevel,FUN=get.binned.ids,lca=lca)))  
    binned <- tab[tab$qseqid%in%binned.ids,c("qseqid","pident","min_pident"),drop=FALSE]
    binned <- binned[!duplicated(binned$qseqid),,drop=FALSE]
    binned <- cbind(binned,lca[match(binned$qseqid,lca$qseqid),taxcols,drop=FALSE])
    idx <- max(which(colnames(binned) %in% taxlevel))+1
    if ( idx < length(colnames(binned)) && nrow(binned)>0) {
        ## all levels below the one where the binning has occured are set to NA
        ## do nothing when taxlevel=S        
        binned[,seq(idx,length(colnames(binned)))] <- NA
    }
    return(binned)
}

pinfo <- function(...,verbose=TRUE) {
    if (verbose) message(paste0("[info] ",...,""))
}

perror <- function(...,fatal=FALSE) {
    message(paste0("[ERROR] ",...,""))
    if (fatal) quit(status=1)
}


get.lowest.common.ancestor <- function(tab) {

    colnames <- c("qseqid","K","P","C","O","F","G","S")
    
    if(nrow(tab)==0) {
        lcasp<-data.frame(matrix(nrow=0,ncol = 8))
        colnames(lcasp)<-colnames
        return(lcasp)
    }
        
    tab$path<-paste(tab$K,tab$P,tab$C,tab$O,tab$F,tab$G,tab$S,sep = ";")
    lcasp = aggregate(tab$path, by=list(tab$qseqid),function(x) lca(x,sep=";"))
    colnames(lcasp)<-c("qseqid","binpath")
    lcasp<-add.unknown.lca(lcasp)
    mat<-do.call(rbind,stringr::str_split(lcasp$binpath,";"))
    lcasp<-as.data.frame(cbind(lcasp$qseqid,mat[,1],mat[,2],mat[,3],mat[,4],mat[,5],mat[,6],mat[,7]))
    colnames(lcasp)<-colnames
    return(lcasp)
}

apply.blacklists <- function(tab,blacklists,level="S",mark.bl="mbk:bl") {
    bl <- NULL
    if (is.null(blacklists)) return(tab)
    if (level=="S") {
        bl <- unique(c(blacklists$genus.level,
                     blacklists$species.level,
                     blacklists$family.level))
    } else {
        if (level=="G") {
            bl=unique(c(blacklists$genus.level,blacklists$family.level))
        } else {
            ## level==F
            bl=blacklists$family.level
        }
    }
    if (length(bl)==0) return(tab)
    tab[tab$taxids %in% bl,level] <- mark.bl
    return(tab)
}

get.top <- function(tab,topN) {
    if (nrow(tab)==0) {
        d<-data.frame(matrix(nrow=0,ncol=1))
        colnames(d) <- c("min_pident")
        tab <- cbind(tab,d)
        return(tab)
    }
    ## top hit for each qseqid
    setDT(tab)
    tab.a <- tab[tab[, .I[pident==max(pident)], by=qseqid]$V1]
    ## discard ties
    tab.a <- tab.a[!duplicated(tab.a$qseqid),,drop=FALSE]
    tab.a <- as.data.frame(tab.a)
    tab <- as.data.frame(tab)
    rownames(tab.a) <- tab.a$qseqid
    tab.a$minp <- tab.a$pident-topN
    tab.a$minp[tab.a$minp<0] <- 0
    ## add minp
    tab$min_pident <- tab.a[tab$qseqid,"minp"]
    tab<-tab[tab$pident>=tab$min_pident,,drop=FALSE]
    tab <- tab[!is.na(tab$qseqid),,drop=FALSE]
    return(tab)
}

## 
add.lineage.df<-function(dframe,taxDir,taxCol="taxids") {
  
    if(!taxCol %in% colnames(dframe)) {stop(paste0("No column called ",taxCol))}

    if ( nrow(dframe) == 0 ) {
        pinfo("Skipping taxonomic rerieval - no data")
        new.cols <- c("old_taxids","K","P","C","O","F","G","S")
        new.df <- data.frame(matrix(nrow=0,ncol=ncol(dframe)+length(new.cols)))
        colnames(new.df) <- c(colnames(dframe),new.cols)
        return(new.df)
    }
    ##write taxids to file
    taxids_fileIn <- tempfile(pattern = "taxids_", tmpdir = tempdir(), fileext = ".txt")
    taxids_fileOut <- tempfile(pattern = "taxids_", tmpdir = tempdir(), fileext = ".out.txt")
    write.table(unique(dframe[,taxCol]),file = taxids_fileIn,row.names = FALSE,col.names = FALSE,quote = FALSE)
    
        ##get taxonomy from taxids and format in 7 levels
    cmd <- paste0("cat ",taxids_fileIn, " | taxonkit lineage --data-dir ", taxDir, " | taxonkit reformat --data-dir ",taxDir," | cut -f 1,3 > ",taxids_fileOut)
    
    system(cmd)
    
    lineage<-as.data.frame(data.table::fread(file = taxids_fileOut,sep = "\t",header=FALSE))
    colnames(lineage)<-gsub("V1","taxids",colnames(lineage))
    colnames(lineage)<-gsub("V2","path",colnames(lineage))
    ##merge with df
    ##message("replacing taxids with updated taxids. Saving old taxids in old_taxids.")
    dframe<-merge(dframe,lineage[,c("taxids","path")],by.x = taxCol,by.y = "taxids")
    dframe$old_taxids<-dframe[,taxCol]
    ##dframe$taxids<-dframe$new_taxids
    dframe$new_taxids <- NULL
    dframe<-cbind(dframe,do.call(rbind, stringr::str_split(dframe$path,";")))
    colnames(dframe)[(length(dframe)-6):length(dframe)]<-c("K","P","C","O","F","G","S")
    dframe$K<-as.character(dframe$K)
    dframe$P<-as.character(dframe$P)
    dframe$C<-as.character(dframe$C)
    dframe$O<-as.character(dframe$O)
    dframe$F<-as.character(dframe$F)
    dframe$G<-as.character(dframe$G)
    dframe$S<-as.character(dframe$S)
    
    ##change empty cells to "unknown"
    ##dframe[,(length(dframe)-6):length(dframe)][dframe[,(length(dframe)-6):length(dframe)]==""]<- "unknown"
    
    ## tnf: taxid not found
    dframe[,(length(dframe)-6):length(dframe)][dframe[,(length(dframe)-6):length(dframe)]==""]<- "mbk:tnf"
    
    dframe$path <- NULL
    unlink(taxids_fileIn)
    unlink(taxids_fileOut)
    
    return(dframe)
}

get.taxids.children <-function(taxids,taxonomy_data_dir=NULL){

    if(is.null(taxids)) return(NULL);
    
    staxids<-as.integer(as.character(unique(taxids)))
    ## temp.file - use default temporary directory
    taxids_fileIn <- tempfile(pattern = "taxids_", tmpdir = tempdir(), fileext = ".txt")
    taxids_fileOut <- tempfile(pattern = "taxids_", tmpdir = tempdir(), fileext = ".out.txt")
    write.table(staxids,file = taxids_fileIn,row.names = F,col.names = F,quote = F)

    ###############
    ## get children
    ## usw a wrapper to be able to deal with big lists of taxids
    cmd <- paste0("taxonkit_children.sh ",taxids_fileIn," ",taxids_fileOut)
    if (!is.null(taxonomy_data_dir)) {
        cmd <- paste0(cmd," ",taxonomy_data_dir)
    }
    system(cmd)
    ## 
    children<-data.table::fread(file = taxids_fileOut,header=FALSE,sep = "\t",quote="",data.table = F)
    children<-children[!is.na(children$V1),]
    unlink(taxids_fileIn)
    unlink(taxids_fileOut)
    return(children)
}


add.unknown.lca<-function(lca.out){
  
  lca.out$binpath[is.na(lca.out$binpath)]<-"mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca"
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==5]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==5],";mbk:nb-lca")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==4]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==4],";mbk:nb-lca;mbk:nb-lca")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==3]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==3],";mbk:nb-lca;mbk:nb-lca;mbk:nb-lca")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==2]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==2],";mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==1]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==1],";mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==0]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==0],";mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca;mbk:nb-lca")
  
  return(lca.out)
}
