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

metabinkit.version <- "0.0.4"

## Ensure that we are using a recent version of R
##
R.version <- getRversion()
currentVersion <- sprintf("%d.%d", R.version$major, R.version$minor)
if ( R.version$major < 3 || (R.version$major=3 && R.version$minor<6) ) {
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
                    species.blacklist=NULL,
                    genus.blacklist=NULL,
                    family.blacklist=NULL,
                    #disabledTaxaFiles=NULL,
                    disabledTaxaOut=NULL, ## file prefix
                    ## force=F, ## ??
                    ## full.force=F, ##??
                    filter.col=NULL,
                    filter=NULL,
                    consider_sp.=FALSE,
                    quiet=FALSE) {
    
    ####################
    ## validate arguments
    if(is.null(taxDir)) perror(fatal=TRUE,"taxDir not specified");
    if(!file.exists(ifile)) perror(fatal=TRUE,"file ", ifile, "not found"); 

    ## all arguments look ok, carry on...
    library(data.table)
    options(datatable.fread.input.cmd.message=FALSE)

    ## start timer
    t1<-Sys.time()
    
    ## would prefer that file was loader prior to this function being called
    ## lets keep it for now
    btab.o<-data.table::fread(ifile,sep="\t",data.table = F)
    pinfo(verbose=!quiet,"Read ",nrow(btab.o)," entries from ",ifile)
    ## are the expected columns present?
    ## qseqid pident taxids
    expected.cols <- c("qseqid","pident","taxids")
    if(!is.null(filter.col) && !is.null(filter)) {
        expected.cols <- c(expected.cols,filter.col)
    }
    not.found <- expected.cols[!expected.cols%in%colnames(btab.o)]
    if ( length(not.found) > 0 ) perror(fatal=TRUE,"missing columns in input table:",paste(not.found,collapse=","))

    ## Filter
    if(!is.null(filter.col) && !is.null(filter)) {
        pinfo("Filtering table (",nrow(btab.o),") using ",filter.col," column.")
        btab.o <- btab.o[!btab.o[,filter.col]%in%filter,,drop=FALSE]
        pinfo("Filtered table (",nrow(btab.o),") using ",filter.col," column.")
    }

    
    ## check if lineage information is available
    expected.tax.cols <- c("K","P","C","O","F","G","S")
    not.found <- expected.tax.cols[!expected.tax.cols%in%colnames(btab.o)]
    if ( length(not.found) > 0 ) {
        perror(fatal=FALSE," WARNING! missing columns in input table with taxonomic information:",paste(not.found,collapse=","))
        ## 
        btab.o <- add.lineage.df(btab.o,taxDir=taxDir,taxCol="taxids")
        not.found <- expected.tax.cols[!expected.tax.cols%in%colnames(btab.o)]
        if ( length(not.found) > 0 ) {
            perror(fatal=TRUE," Missing columns in input table with taxonomic information:",paste(not.found,collapse=","))
        }
    }
    
    ## keep only the necessary columns
    btab <- btab.o[,c(expected.cols,expected.tax.cols),drop=FALSE]
    rm(btab.o)

    ## record the numbers
    stats <- list()
    stats$total_hits <- nrow(btab)
    stats$total_queries<- length(unique(btab$qseqid))

    ##################################################################
    ## Blacklisting
    blacklists <- list(species.level=species.blacklist,
                  family.level=family.blacklist,
                  genus.level=genus.blacklist)
    ##
    blacklists.children <- lapply(blacklists,get.taxids.children,taxonomy_data_dir=taxDir)

    ## some info...
    if (!is.null(blacklists$species.level)) pinfo(verbose=!quiet,"# Taxa disabled at species level:",length(blacklists.children$species.level))
    if (!is.null(blacklists$genus.level)) pinfo(verbose=!quiet,"# Taxa disabled at genus level:",length(blacklists.children$genus.level))
    if (!is.null(blacklists$family.level)) pinfo(verbose=!quiet,"# Taxa disabled at family level:",length(blacklists.children$family.level))

    n.bef <- nrow(btab)
    btab<-apply.blacklists(btab,blacklists.children,level="species")
    btab<-apply.blacklists(btab,blacklists.children,level="genus")
    btab<-apply.blacklists(btab,blacklists.children,level="family")
    n.aft <- nrow(btab)
    stats$blacklisted <- n.bef-n.aft
    pinfo("Entries blacklisted at species/genus/family level:",stats$blacklisted)
    ##################################################################
    ## unassigned/not binned
    btab.u <- btab[!duplicated(btab$qseqid),,drop=FALSE]
    ##################################################################
    ##species-level assignments
    pinfo(verbose=!quiet,"binning at species level")    
    btab.sp<-btab[btab$S!="unknown",,drop=FALSE]
    binned.sp <- NULL
    if (nrow(btab.sp)>0) {
        ## apply filters
        above.threshold <- btab.sp$pident>=spident
        pinfo(verbose=!quiet,"excluding ",sum(!above.threshold)," entries with pident below ",spident)
        
        not.passing.ids <- unique(btab.sp$qseqid[!above.threshold])
        btab.sp<-btab.sp[above.threshold,,drop=FALSE]
        not.passing.ids <- not.passing.ids[!not.passing.ids%in%btab.sp$qseqid]
        btab.u[btab.u$qseqid%in%not.passing.ids,"S"] <- NA
        
        if(consider_sp.==F){
            pinfo(verbose=!quiet,"Not considering species with 'sp.', numbers or more than one space")
            count.bef <- nrow(btab.sp)
            toremove <- -grep(" sp\\.",btab.sp$S,ignore.case = TRUE,invert=FALSE)
            if (length(toremove)>0)
                btab.sp<-btab.sp[toremove,,drop=FALSE]

            ## More than two spaces
            toremove <- -grep("[^\\s]+\\s+[^\\s]+\\s+[^\\s].*",btab.sp$S,ignore.case = TRUE,perl=TRUE,invert=FALSE)
            if (length(toremove)>0)
                btab.sp <- btab.sp[toremove,,drop=FALSE]

            ## shouldn't the number and spaces be a diffent option?
            toremove <- -grep("\\d",btab.sp$S,perl=TRUE,invert=FALSE)
            if (length(toremove)>0)
                btab.sp<- btab.sp[toremove,,drop=FALSE]
            count.aft <- nrow(btab.sp)
            sp.filter.n <- count.bef-count.aft
            stats$species.level.sp.filter <- sp.filter.n
            pinfo(verbose=!quiet,"Excluded ",sp.filter.n," entries")
        } else {
            pinfo(verbose=!quiet,"Considering species with 'sp.', numbers or more than one space")
            stats$species.level.sp.filter <- 0
        }
        
        ## get top
        pinfo(verbose=!quiet,"applying species top threshold of ",topS)
        btab.sp<-get.top(btab.sp,topN=topS)
        ## LCA
        lca.sp <- get.lowest.common.ancestor(btab.sp)
        binned.sp <- get.binned(btab.sp,lca.sp,"S",expected.tax.cols)
        btab <- btab[!btab$qseqid%in%binned.sp$qseqid,,drop=FALSE]
        rm(lca.sp)
    }
    if (nrow(btab)>0)
        btab$S <- NA
    rm(btab.sp)
    stats$binned.species.level <- nrow(binned.sp)
    pinfo(verbose=!quiet,"binned ",nrow(binned.sp)," sequences at species level")
    ##################################################################
    ##genus-level assignments
    pinfo(verbose=!quiet,"binning at genus level") 
    ##reason - can have g=unknown and s=known (e.g. Ranidae isolate), these should be removed
    ##can have g=unknown and s=unknown (e.g. Ranidae), these should be removed
    ##can have g=known and s=unknown (e.g. Leiopelma), these should be kept
    btab.g<-btab[btab$G!="unknown",,drop=FALSE]  
    binned.g <- NULL
    if ( nrow(btab.g) > 0 ) {
        ## apply filters
                                        #btab.g<-apply.blacklists(btab.g,blacklists.children,level="genus")
        above.threshold <- btab.g$pident>=gpident
        pinfo(verbose=!quiet,"excluding ",sum(!above.threshold)," entries with pident below ",gpident)
        not.passing.ids <- unique(btab.g$qseqid[!above.threshold])
        btab.g<-btab.g[above.threshold,,drop=FALSE]
        not.passing.ids <- not.passing.ids[!not.passing.ids%in%btab.g$qseqid]
        btab.u[btab.u$qseqid%in%not.passing.ids,"G"] <- NA

        ## get top
        pinfo(verbose=!quiet,"applying genus top threshold of ",topG)
        btab.g<-get.top(btab.g,topN=topG)
        ## LCA
        lca.g <- get.lowest.common.ancestor(btab.g)
        binned.g <- get.binned(btab.g,lca.g,"G",expected.tax.cols)
        
        btab <- btab[!btab$qseqid%in%binned.g$qseqid,,drop=FALSE]
        rm(lca.g)
    }
    if (nrow(btab)>0)
        btab$G <- NA

    rm(btab.g)
    stats$binned.genus.level <- nrow(binned.g)
    pinfo(verbose=!quiet,"binned ",nrow(binned.g)," sequences at genus level")
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
    btab.f<-btab[btab$F!="unknown" || btab$G!="unknown" || btab$S!="unknown",,drop=FALSE]
    btab.f <- btab.f[!is.na(btab.f$qseqid),,drop=FALSE]
    binned.f <- NULL
    ## apply filters
    ##btab.f<-apply.blacklists(btab.f,blacklists.children,level="family")
    if ( nrow(btab.f) > 0 ) {
        above.threshold <- btab.f$pident>=fpident
        pinfo(verbose=!quiet,"excluding ",sum(!above.threshold)," entries with pident below ",fpident)
        
        not.passing.ids <- unique(btab.f$qseqid[!above.threshold])
        btab.f<-btab.f[above.threshold,,drop=FALSE]
        not.passing.ids <- not.passing.ids[!not.passing.ids%in%btab.f$qseqid]
        btab.u[btab.u$qseqid%in%not.passing.ids,"F"] <- NA
        
        pinfo(verbose=!quiet,"applying family top threshold of ",topF)
        btab.f<-get.top(btab.f,topN=topF)
        ## LCA
        lca.f <- get.lowest.common.ancestor(btab.f)
        binned.f <- get.binned(btab.f,lca.f,"F",expected.tax.cols)
        btab <- btab[!btab$qseqid%in%binned.f$qseqid,,drop=FALSE]
        rm(lca.f)
    }
    if (nrow(btab)>0)
        btab$F <- NA
    rm(btab.f)
    stats$binned.family.level <- nrow(binned.f)
    pinfo(verbose=!quiet,"binned ",nrow(binned.f)," sequences at family level")
    ##################################################################
    ##higher-than-family-level assignments
    pinfo(verbose=!quiet,"binning at higher-than-family level")
    btab.htf<-btab[btab$K!="unknown",,drop=FALSE]
    ## apply filters
    above.threshold <- btab.htf$pident>=abspident
    pinfo(verbose=!quiet,"excluding ",sum(!above.threshold)," entries with pident below ",abspident)
    not.passing.ids <- unique(btab.htf$qseqid[!above.threshold])
    btab.htf<-btab.htf[above.threshold,,drop=FALSE]
    not.passing.ids <- not.passing.ids[!not.passing.ids%in%btab.htf$qseqid]
    btab.u[btab.u$qseqid%in%not.passing.ids,c("O","C","P","K")] <- NA
    pinfo(verbose=!quiet,"applying htf top threshold of ",topAbs)
    btab.htf<-get.top(btab.htf,topN=topAbs)
    ## LCA
    lca.htf <- get.lowest.common.ancestor(btab.htf)
    binned.htf <- get.binned(btab.htf,lca.htf,c("O","C","P","K"),expected.tax.cols)
    rm(lca.htf)
    rm(btab.htf)
    pinfo(verbose=!quiet,"binned ",nrow(binned.htf)," sequences at higher than family level")
    stats$binned.htf.level <- nrow(binned.htf)
    
    #######################################################################
    ##combine binned/assigned
    atab <- rbind(binned.sp,binned.g,binned.f,binned.htf)
    pinfo(verbose=!quiet,"Total number of binned ",nrow(atab)," sequences")
    
    ## 
    ###################################################################
    ## unassigned/not binned
    ## remove the binned qseqid    
    btab.u <- btab.u[!btab.u$qseqid%in%atab$qseqid,,drop=FALSE]
    ## remove the extra column
    btab.u <- btab.u[,!colnames(btab.u)%in%c("taxids"),drop=FALSE]
    if (nrow(btab.u)>0) {
        ##btab.u[,expected.tax.cols] <- "unknown"
        btab.u$min_pident <- NA
    } else {
        ## empty matrix
        d<-data.frame(matrix(nrow=0,ncol=1))
        colnames(d) <- c("min_pident")
        btab.u <- cbind(btab.u,d)
    }
    
    stats$not.binned <- nrow(btab.u)
    pinfo(verbose=!quiet,"not binned ",nrow(btab.u)," sequences")

    ftab <- rbind(atab,btab.u[,colnames(atab),drop=FALSE])
    ############################################################
    ## Wrapping up
    t2<-Sys.time()
    t3<-round(difftime(t2,t1,units = "mins"),digits = 2)

    #write.table(x = com_level,file = out,sep="\t",quote = F,row.names = F)
  
    pinfo(verbose=!quiet,"Complete. ",stats$total_hits, " hits from ", stats$total_queries," queries processed in ",t3," mins.")
    
    pinfo(verbose=!quiet,"Note: If none of the hits for a BLAST query pass the binning thesholds, the results will be NA for all levels.
                 If the LCA for a query is above kingdom, e.g. cellular organisms or root, the results will be 'unknown' for all levels.
                 Queries that had no BLAST hits, or did not pass the filter.blast step will not appear in results.  ")
    res <- list(table=ftab,stats=stats)
    return(res)
}


get.binned <- function(tab,lca,taxlevel,taxcols=c("K","P","C","O","F","G","S")) {
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
        ## all levels below the one where the binned was made are set to NA
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

apply.blacklists <- function(tab,blacklists,level="species") {
    bl <- NULL
    if (is.null(blacklists)) return(tab)
    if (level=="species") {
            bl <- unique(blacklists$species.level)
    } else {
        if (level=="genus") {
            bl=unique(blacklists$genus.level)
        } else {
            bl=unique(blacklists$family.level)
        }
    }
    tab <- tab[!tab$taxids %in% bl,,drop=FALSE]
    return(tab)
}

get.topdf <- function(pident,groupby,top) {
    topdf <- aggregate(x=pident,by=list(groupby),FUN=max)
    colnames(topdf)<-c("qseqid","pident")
    topdf$min_pident<-topdf$pident-top
    return(topdf)
}

get.top <- function(tab,topN) {
    if (nrow(tab)==0) {
        d<-data.frame(matrix(nrow=0,ncol=1))
        colnames(d) <- c("min_pident")
        tab <- cbind(tab,d)
        return(tab)
    }
    topdf <- get.topdf(tab[,"pident"],tab$qseqid,topN)
    tab$min_pident <- topdf[match(tab$qseqid,topdf$qseqid),"min_pident"]
    tab<-tab[tab$pident>tab$min_pident,,drop=FALSE]
    tab <- tab[!is.na(tab$qseqid),,drop=FALSE]
    return(tab)
}

## 
add.lineage.df<-function(dframe,taxDir,taxCol="taxids") {
  
    if(!taxCol %in% colnames(dframe)) {stop(paste0("No column called ",taxCol))}

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
    #dframe$taxids<-dframe$new_taxids
    dframe$new_taxids=NULL
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
    dframe[,(length(dframe)-6):length(dframe)][dframe[,(length(dframe)-6):length(dframe)]==""]<- "unknown"
    
    
    dframe$path=NULL
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
    ## this code will not work if the list of ids is big (~200 ids)
    #system2(command = "taxonkit",args =  c("list","--ids",paste(as.character(df$taxids),collapse = ","),"--indent", "''","--data-dir",ncbiTaxDir)
                                        #      ,stdout = taxids_fileOut,stderr = "",wait = T)
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
  
  lca.out$binpath[is.na(lca.out$binpath)]<-"unknown;unknown;unknown;unknown;unknown;unknown;unknown"
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==5]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==5],";unknown")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==4]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==4],";unknown;unknown")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==3]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==3],";unknown;unknown;unknown")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==2]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==2],";unknown;unknown;unknown;unknown")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==1]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==1],";unknown;unknown;unknown;unknown;unknown")
  lca.out$binpath[stringr::str_count(lca.out$binpath,";")==0]<-paste0(lca.out$binpath[stringr::str_count(lca.out$binpath,";")==0],";unknown;unknown;unknown;unknown;unknown;unknown")
  
  return(lca.out)
}
