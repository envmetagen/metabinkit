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

metabinkit.version <- "0.0.1"

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



metabin <- function(ifile,
                    taxDir,
                    out,
                    spident=98,
                    gpident=95,
                    fpident=92,
                    abspident=80,
                    topS=1,
                    topG=1,
                    topF=1,
                    topAbs=1, # Bastian: what is this parameter
                    species.blacklist=NULL,
                    genus.blacklist=NULL,
                    family.blacklist=NULL,
                    #disabledTaxaFiles=NULL,
                    disabledTaxaOut=NULL, ## file prefix
                    force=F, ## ??
                    full.force=F, ##??
                    consider_sp.=F) {

    ####################
    ## validate arguments
    if(is.null(out)) stop("out not specified")
    if(is.null(taxDir)) stop("taxDir not specified")
    ## TODO!!!!!!!!!!!!!
    
    ## all arguments look ok, carry on...
    library(data.table)
    options(datatable.fread.input.cmd.message=FALSE)

    t1<-Sys.time()
    ## would prefer that file was loader prior to this function being called
    ## lets keep it for now
    btab<-data.table::fread(ifile,sep="\t",data.table = F)

    ## TODO: validate table
    ## are the expected columns present?
    ## qseqid pident taxids 
    ##preparing some things for final step
    total_hits<-length(btab$qseqid) #for info later
    total_queries<-length(unique(btab$qseqid))
    qseqids<-as.data.frame(unique(btab$qseqid))
    qseqids$qseqid<-qseqids$`unique(btab$qseqid)`
    qseqids$`unique(btab$qseqid)`=NULL

    blacklists <- list(species.level=species.blacklist,
                  family.level=family.blacklist,
                  genus.level=genus.blacklist)

    ## TODO add taconomy dir?
    ##lapply(blacklists,get.taxids.children,taxonomy_data_dir=
    blacklists.children <- lapply(blacklists,get.taxids.children)

    ## print? save to a file?
    message("The following taxa are disabled at species level")
    message("The following taxa are disabled at genus level")
    message("The following taxa are disabled at family level")
    #

    ######################################################
    ##species-level assignments
    message("binning at species level")
    message("applying species top threshold of ",topS)
    btabsp<-btab[btab$S!="unknown",,drop=FALSE]
    btabsp<-get.top(btabsp,topN=topS)
    
    ## Bastian: shouldnt all  blacklisted ids be removed before get thetop hits??
    btabsp<-apply.blacklists(btabsp,blacklists.children,level="species")
    
    if(consider_sp.==F){
        message("Not considering species with 'sp.', numbers or more than one space")
        if(length(grep(" sp\\.",btabsp$S,ignore.case = T))>0) btabsp<-btabsp[-grep(" sp\\.",btabsp$S,ignore.case = T),]
        if(length(grep(" .* .*",btabsp$S,ignore.case = T))>0) btabsp<-btabsp[-grep(" .* .*",btabsp$S,ignore.case = T),]
        if(length(grep("[0-9]",btabsp$S))>0) btabsp<-btabsp[-grep("[0-9]",btabsp$S),]
    } else(message("Considering species with 'sp.', numbers or more than one space"))

    # filter - why isn't this applied first?
    btabsp<-btabsp[btabsp$pident>spident,,drop=FALSE]
    ## LCA
    lcasp <- get.lowest.common.ancestor(btabsp)
    rm(btabsp)
    
    ##################################################################
    ##genus-level assignments
    message("binning at genus level") 
    btabg<-btab[btab$G!="unknown",,drop=FALSE]  
    ##reason - can have g=unknown and s=known (e.g. Ranidae isolate), these should be removed
    ##can have g=unknown and s=unknown (e.g. Ranidae), these should be removed
    ##can have g=known and s=unknown (e.g. Leiopelma), these should be kept
  
    message("applying genus top threshold of ",topG)
    btabg<-get.top(btabg,topN=topG)
    btabg<-apply.blacklists(btabg,blacklists.children,level="genus")
    # filter
    btabg<-btabg[btabg$pident>gpident,,drop=FALSE] 
    ## LCA
    lcag <- get.lowest.common.ancestor(btabg)  
    rm(btabg)
    #############################
    ##family-level assignments
    message("binning at family level")
    message("applying family top threshold of ",topF)
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
  
    btabf<-btab[!(btab$F=="unknown" & btab$G=="unknown" & btab$S=="unknown"),,drop=FALSE]  ####line changed 
    btabf<-btabf[!(btabf$F=="unknown" & btabf$G=="unknown"),,drop=FALSE] ####line changed 
  
    btabf<-get.top(btabf,topN=topF)
    btabf<-apply.blacklists(btabf,blacklists.children,level="family")
    # filter
    btabf<-btabf[btabf$pident>fpident,,drop=FALSE]
    lcaf <- get.lowest.common.ancestor(btabf)  
    rm(btabf)

    #####################################
    ##higher-than-family-level assignments
    message("binning at higher-than-family level")
    message("applying htf top threshold of ",topAbs)
    btabhtf<-btab[btab$K!="unknown",,drop=FALSE]
  
    btabhtf<-get.top(btabhtf,topN=topAbs)
    ## filter
    btabhtf<-btabhtf[btabhtf$pident>abspident,,drop=FALSE]
    ## LCA
    lcahtf <- get.lowest.common.ancestor(btabhtf)  
    rm(btabhtf)
  
    ###################################################
    ##combine
    sp_level<-lcasp[lcasp$S!="unknown",]
    g_level<-lcag[lcag$G!="unknown",]
    if(nrow(g_level)>0) g_level$S<-NA
    g_level<-g_level[!g_level$qseqid %in% sp_level$qseqid,]
    f_level<-lcaf[lcaf$F!="unknown",]
    if(nrow(f_level)>0) {
        f_level$G<-NA
        f_level$S<-NA
    }
    f_level<-f_level[!f_level$qseqid %in% sp_level$qseqid,]
    f_level<-f_level[!f_level$qseqid %in% g_level$qseqid,]
    
    abs_level<-lcahtf
    if(nrow(abs_level)>0) {
        abs_level$G<-NA
        abs_level$S<-NA
        abs_level$F<-NA
    }
    abs_level<-abs_level[!abs_level$qseqid %in% sp_level$qseqid,]
    abs_level<-abs_level[!abs_level$qseqid %in% g_level$qseqid,]
    abs_level<-abs_level[!abs_level$qseqid %in% f_level$qseqid,]
    
    com_level<-rbind(sp_level,g_level,f_level,abs_level)
    com_level<-merge(x=qseqids, y = com_level, by = "qseqid",all.x = T)

    ############################################################
    ## Wrapping up
    ##info
    t2<-Sys.time()
    t3<-round(difftime(t2,t1,units = "mins"),digits = 2)
  
    #write.table(x = com_level,file = out,sep="\t",quote = F,row.names = F)
  
    message(c("Complete. ",total_hits, " hits from ", total_queries," queries processed in ",t3," mins."))
    
    message("Note: If none of the hits for a BLAST query pass the binning thesholds, the results will be NA for all levels.
                 If the LCA for a query is above kingdom, e.g. cellular organisms or root, the results will be 'unknown' for all levels.
                 Queries that had no BLAST hits, or did not pass the filter.blast step will not appear in results.  ")
    return(com_level)
}


get.lowest.common.ancestor <- function(tab) {

    colnames <- c("qseqid","K","P","C","O","F","G","S")
    
    if(nrow(tab)==0) {
        lcasp<-data.frame(matrix(nrow=1,ncol = 8))
        colnames(lcasp)<-colnames
        return(lcasp)
    }
        
    tab$path<-paste(btabsp$K,tab$P,tab$C,tab$O,tab$F,tab$G,tab$S,sep = ";")
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
            bl <- unique(unlist(blacklists))
    } else {
        if (level=="genus") {
            bl=unique(c(blacklists$family.level,blacklists$genus.level))
        } else {
            bl=unique(c(blacklists$family.level))
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

    if (nrow(tab)==0) return(tab)
    topdf <- get.topdf(tab[,"pident"],tab$qseqid,topN)
    tab$min_pident <- topdf[match(tab$qseqid,tab$qseqid),"min_pident",drop=FALSE]
    tab<-tab[tab$pident>tab$min_pident,drop=FALSE]
}

## Bastian: old taxids? what do you don when you have multiple taxids in staxids?
add.lineage.df<-function(dframe,taxDir,taxCol="taxids",as.taxids=FALSE){
  
    if(!taxCol %in% colnames(dframe)) {stop(paste0("No column called ",taxCol))}

    ##write taxids to file
    taxids_fileA<-paste0("taxids",as.numeric(Sys.time()),".txt")
    write.table(unique(dframe[,taxCol]),file = taxids_fileA,row.names = F,col.names = F,quote = F)
    
    ##get taxonomy from taxids and format in 7 levels
    taxids_fileB<-paste0("taxids",as.numeric(Sys.time()),".txt")
    system2(command = "taxonkit",args =  c("lineage","-r",taxids_fileA,"-c","--data-dir",taxDir)
           ,stdout = taxids_fileB,stderr = "",wait = T)
    taxids_fileC<-paste0("taxids",as.numeric(Sys.time()),".txt")
    if(as.taxids==F){
        system2(command = "taxonkit",args =  c("reformat",taxids_fileB,"-i",3,"--data-dir",taxDir)
               ,stdout = taxids_fileC,stderr = "",wait = T)
    } else {
        system2(command = "taxonkit",args =  c("reformat","-t", taxids_fileB,"-i",3,"--data-dir",taxDir)
               ,stdout = taxids_fileC,stderr = "",wait = T)
    }
    lineage<-as.data.frame(data.table::fread(file = taxids_fileC,sep = "\t"))
    colnames(lineage)<-gsub("V1","taxids",colnames(lineage))
    colnames(lineage)<-gsub("V2","new_taxids",colnames(lineage))
    if(as.taxids==F){
        colnames(lineage)<-gsub("V5","path",colnames(lineage))
    } else {
    colnames(lineage)<-gsub("V6","path",colnames(lineage))
    }
    
    ##merge with df
    ##message("replacing taxids with updated taxids. Saving old taxids in old_taxids.")
    dframe<-merge(dframe,lineage[,c("taxids","new_taxids","path")],by.x = taxCol,by.y = "taxids")
    dframe$old_taxids<-dframe[,taxCol]
    dframe$taxids<-dframe$new_taxids
    dframe$new_taxids=NULL
    dframe<-cbind(dframe,do.call(rbind, stringr::str_split(dframe$path,";")))
    colnames(dframe)[(length(dframe)-6):length(dframe)]<-c("K","P","C","O","F","G","S")
    if(as.taxids==F){
        dframe$K<-as.character(dframe$K)
        dframe$P<-as.character(dframe$P)
        dframe$C<-as.character(dframe$C)
        dframe$O<-as.character(dframe$O)
        dframe$F<-as.character(dframe$F)
        dframe$G<-as.character(dframe$G)
        dframe$S<-as.character(dframe$S)
        
                                        #change empty cells to "unknown"
        dframe[,(length(dframe)-6):length(dframe)][dframe[,(length(dframe)-6):length(dframe)]==""]<- "unknown"
    }
    
    dframe$path=NULL
    unlink(taxids_fileA)
    unlink(taxids_fileB)
    unlink(taxids_fileC)
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
    children<-data.table::fread(file = taxids_fileOut,sep = "\t",data.table = F)
    children<-children[!is.na(children$V1),]
  
    unlink(taxids_fileIn)
    unlink(taxids_fileOut)
    return(children)
}



##########################################################
## original code
bin.blast3<-function(filtered_blastfile,
                     ncbiTaxDir,
                     out,
                     spident=98,
                     gpident=95,
                     fpident=92,
                     abspident=80,
                     topS=1,
                     topG=1,
                     topF=1,
                     topAbs=1,
                     disabledTaxaFiles=NULL,
                     disabledTaxaOut=NULL,
                     force=F,
                     full.force=F,
                     consider_sp.=F) {
  t1<-Sys.time()
  
  if(is.null(out)) stop("out not specified")
  if(is.null(ncbiTaxDir)) stop("ncbiTaxDir not specified")

  ###################################################
  
  btab<-data.table::fread(filtered_blastfile,sep="\t",data.table = F)
  
  #preparing some things for final step
  total_hits<-length(btab$qseqid) #for info later
  total_queries<-length(unique(btab$qseqid))
  qseqids<-as.data.frame(unique(btab$qseqid))
  qseqids$qseqid<-qseqids$`unique(btab$qseqid)`
  qseqids$`unique(btab$qseqid)`=NULL
  
  #read and check disabled taxa file(s) 
  if(!is.null(disabledTaxaFiles)){
    
    require(treemap)
    
    disabledTaxaDf<-merge.and.check.disabled.taxa.files(disabledTaxaFiles,disabledTaxaOut,force = force,full.force = full.force)
    
    #get taxids at 7 levels
    disabledTaxaDf<-add.lineage.df(disabledTaxaDf,ncbiTaxDir,as.taxids = T)
    
    disabledSpecies<-disabledTaxaDf[disabledTaxaDf$disable_species==T,]
    disabledSpecies<-disabledSpecies[!is.na(disabledSpecies$taxids),]
    #get children of all disabled species
    disabledSpecies$taxids<-disabledSpecies$S
    if(nrow(disabledSpecies)>0)  {
      childrenS<-get.children.taxonkit(disabledSpecies) 
    } else {
      childrenS<-NULL
    } 
    
    disabledGenus<-disabledTaxaDf[disabledTaxaDf$disable_genus==T,]
    disabledGenus<-disabledGenus[!is.na(disabledGenus$taxids),]
    #get children of all disabled genera
    disabledGenus$taxids<-disabledGenus$G
    if(nrow(disabledGenus)>0)  {
      childrenG<-get.children.taxonkit(disabledGenus) 
    } else {
      childrenG<-NULL
    }
    
    
    disabledFamily<-disabledTaxaDf[disabledTaxaDf$disable_family==T,]
    disabledFamily<-disabledFamily[!is.na(disabledFamily$taxids),]
    #get children of all disabled families
    disabledFamily$taxids<-disabledFamily$F
    if(nrow(disabledFamily)>0)  {
      childrenF<-get.children.taxonkit(disabledFamily) 
    } else {
      childrenF<-NULL
    }
    
    message("The following taxa are disabled at species level")
    if(!is.null(childrenS)){
      childrenAlldf<-as.data.frame(unique(c(childrenS,childrenG,childrenF)))
      colnames(childrenAlldf)<-"taxids"
      childrenNames<-add.lineage.df(childrenAlldf,ncbiTaxDir)
      childrenNames$pathString<-paste("Family",childrenNames$F,childrenNames$G,childrenNames$S,sep = "/")
      childrenNames$pathString<-lapply(childrenNames$pathString, gsub, pattern = "unknown", replacement = "", fixed = TRUE)
      disabledtree <- data.tree::as.Node(childrenNames)
      print(disabledtree,limit = NULL)
    } else (message("No species disabled"))
    
    message("The following taxa are disabled at genus level")
    if(!is.null(childrenG)){
      childrenAlldf<-as.data.frame(unique(c(childrenG,childrenF)))
      colnames(childrenAlldf)<-"taxids"
      childrenNames<-add.lineage.df(childrenAlldf,ncbiTaxDir)
      childrenNames$pathString<-paste("Family",childrenNames$F,childrenNames$G,sep = "/")
      childrenNames$pathString<-lapply(childrenNames$pathString, gsub, pattern = "unknown", replacement = "", fixed = TRUE)
      disabledtree <- data.tree::as.Node(childrenNames)
      print(disabledtree,limit = NULL)
    } else (message("No genera disabled"))
    
    
    message("The following taxa are disabled at family level")
    if(!is.null(childrenF)){
      childrenAlldf<-as.data.frame(unique(c(childrenF)))
      colnames(childrenAlldf)<-"taxids"
      childrenNames<-add.lineage.df(childrenAlldf,ncbiTaxDir)
      childrenNames$pathString<-paste("Family",childrenNames$F,sep = "/")
      childrenNames$pathString<-lapply(childrenNames$pathString, gsub, pattern = "unknown", replacement = "", fixed = TRUE)
      disabledtree <- data.tree::as.Node(childrenNames)
      print(disabledtree,limit = NULL)
    } else (message("No families disabled"))
  }
  
  #species-level assignments
  message("binning at species level")
  
  btabsp<-btab[btab$S!="unknown",]
  
  message("applying species top threshold of ",topS)
  topdf<-aggregate(x = btabsp[,"pident"],by=list(btabsp$qseqid),FUN = max)
  colnames(topdf)<-c("qseqid","pident")
  topdf$min_pident<-topdf$pident-topS
  btabsp$min_pident<-topdf[match(btabsp$qseqid,topdf$qseqid),"min_pident"]
  btabsp<-btabsp[btabsp$pident>btabsp$min_pident,]
  
  if(!is.null(disabledTaxaFiles)){
    btabsp<-btabsp[!btabsp$taxids %in% unique(c(childrenS,childrenG,childrenF)),]
  }
  
  if(consider_sp.==F){
    message("Not considering species with 'sp.', numbers or more than one space")
    if(length(grep(" sp\\.",btabsp$S,ignore.case = T))>0) btabsp<-btabsp[-grep(" sp\\.",btabsp$S,ignore.case = T),]
    if(length(grep(" .* .*",btabsp$S,ignore.case = T))>0) btabsp<-btabsp[-grep(" .* .*",btabsp$S,ignore.case = T),]
    if(length(grep("[0-9]",btabsp$S))>0) btabsp<-btabsp[-grep("[0-9]",btabsp$S),]
  } else(message("Considering species with 'sp.', numbers or more than one space"))
  
  btabsp<-btabsp[btabsp$pident>spident,]
 
  if(nrow(btabsp)>0){
    
    btabsp$path<-paste(btabsp$K,btabsp$P,btabsp$C,btabsp$O,btabsp$F,btabsp$G,btabsp$S,sep = ";")
    lcasp = aggregate(btabsp$path, by=list(btabsp$qseqid),function(x) lca(x,sep=";"))
    colnames(lcasp)<-c("qseqid","binpath")
    lcasp<-add.unknown.lca(lcasp)
    mat<-do.call(rbind,stringr::str_split(lcasp$binpath,";"))
    lcasp<-as.data.frame(cbind(lcasp$qseqid,mat[,1],mat[,2],mat[,3],mat[,4],mat[,5],mat[,6],mat[,7]))
    colnames(lcasp)<-c("qseqid","K","P","C","O","F","G","S")
    
  } else {
    lcasp<-data.frame(matrix(nrow=1,ncol = 8))
    colnames(lcasp)<-c("qseqid","K","P","C","O","F","G","S")
  }
  rm(btabsp)
  
  #genus-level assignments
  message("binning at genus level") 
  
  btabg<-btab[btab$G!="unknown",]  
  #reason - can have g=unknown and s=known (e.g. Ranidae isolate), these should be removed
  #can have g=unknown and s=unknown (e.g. Ranidae), these should be removed
  #can have g=known and s=unknown (e.g. Leiopelma), these should be kept
  
  message("applying genus top threshold of ",topG)
  topdf<-aggregate(x = btabg[,"pident"],by=list(btabg$qseqid),FUN = max)
  colnames(topdf)<-c("qseqid","pident")
  topdf$min_pident<-topdf$pident-topG
  btabg$min_pident<-topdf[match(btabg$qseqid,topdf$qseqid),"min_pident"]
  btabg<-btabg[btabg$pident>btabg$min_pident,]
  
  if(!is.null(disabledTaxaFiles)){
    btabg<-btabg[!btabg$taxids %in% unique(c(childrenG,childrenF)),]
  }
  
  btabg<-btabg[btabg$pident>gpident,] 
  
  if(nrow(btabg)>0){
    
    btabg$path<-paste(btabg$K,btabg$P,btabg$C,btabg$O,btabg$F,btabg$G,btabg$S,sep = ";")
    lcag = aggregate(btabg$path, by=list(btabg$qseqid),function(x) lca(x,sep=";"))
    colnames(lcag)<-c("qseqid","binpath")
    lcag<-add.unknown.lca(lcag)
    mat<-do.call(rbind,stringr::str_split(lcag$binpath,";"))
    lcag<-as.data.frame(cbind(lcag$qseqid,mat[,1],mat[,2],mat[,3],mat[,4],mat[,5],mat[,6],mat[,7]))
    colnames(lcag)<-c("qseqid","K","P","C","O","F","G","S")
    
  } else {
    lcag<-data.frame(matrix(nrow=1,ncol = 8))
    colnames(lcag)<-c("qseqid","K","P","C","O","F","G","S")
  }
  
  rm(btabg)
  
  #family-level assignments
  message("binning at family level") 
  #can have f=known, g=unknown, s=unknown, these should be kept
  #can have f=unknown, g=known, s=known, these should be kept
  #can have f=unknown, g=known, s=unknown, these should be kept
  #can have f=known, g=known, s=unknown, these should be kept
  #can have f=known, g=known, s=known, these should be kept
  #can have f=unknown, g=known, s=unknown, these should be kept
  #can have f=known, g=unknown, s=known, these should be kept
  
  #can have f=unknown, g=unknown, s=known, these should be removed - 
  #assumes that this case would be a weird entry (e.g. Ranidae isolate)
  
  #can have f=unknown, g=unknown, s=unknown, these should be removed
  
  btabf<-btab[!(btab$F=="unknown" & btab$G=="unknown" & btab$S=="unknown"),]  ####line changed 
  btabf<-btabf[!(btabf$F=="unknown" & btabf$G=="unknown"),] ####line changed 
  
  message("applying family top threshold of ",topF)
  topdf<-aggregate(x = btabf[,"pident"],by=list(btabf$qseqid),FUN = max)
  colnames(topdf)<-c("qseqid","pident")
  topdf$min_pident<-topdf$pident-topF
  btabf$min_pident<-topdf[match(btabf$qseqid,topdf$qseqid),"min_pident"]
  btabf<-btabf[btabf$pident>btabf$min_pident,]
  
  if(!is.null(disabledTaxaFiles)){
    btabf<-btabf[!btabf$taxids %in% unique(c(childrenF)),]
  }
  
  btabf<-btabf[btabf$pident>fpident,]
  
  if(nrow(btabf)>0){
    
    btabf$path<-paste(btabf$K,btabf$P,btabf$C,btabf$O,btabf$F,btabf$G,btabf$S,sep = ";")
    lcaf = aggregate(btabf$path, by=list(btabf$qseqid),function(x) lca(x,sep=";"))
    colnames(lcaf)<-c("qseqid","binpath")
    lcaf<-add.unknown.lca(lcaf)
    mat<-do.call(rbind,stringr::str_split(lcaf$binpath,";"))
    lcaf<-as.data.frame(cbind(lcaf$qseqid,mat[,1],mat[,2],mat[,3],mat[,4],mat[,5],mat[,6],mat[,7]))
    colnames(lcaf)<-c("qseqid","K","P","C","O","F","G","S")
    
  } else {
    lcaf<-data.frame(matrix(nrow=1,ncol = 8))
    colnames(lcaf)<-c("qseqid","K","P","C","O","F","G","S")
  }
  
  rm(btabf)
  
  #higher-than-family-level assignments
  message("binning at higher-than-family level")
  btabhtf<-btab[btab$K!="unknown",]
  
  message("applying htf top threshold of ",topAbs)
  topdf<-aggregate(x = btabhtf[,"pident"],by=list(btabhtf$qseqid),FUN = max)
  colnames(topdf)<-c("qseqid","pident")
  topdf$min_pident<-topdf$pident-topAbs
  btabhtf$min_pident<-topdf[match(btabhtf$qseqid,topdf$qseqid),"min_pident"]
  btabhtf<-btabhtf[btabhtf$pident>btabhtf$min_pident,]
  
  btabhtf<-btabhtf[btabhtf$pident>abspident,]
  
  if(nrow(btabhtf)>0){
    
    btabhtf$path<-paste(btabhtf$K,btabhtf$P,btabhtf$C,btabhtf$O,btabhtf$F,btabhtf$G,btabhtf$S,sep = ";")
    lcahtf = aggregate(btabhtf$path, by=list(btabhtf$qseqid),function(x) lca(x,sep=";"))
    colnames(lcahtf)<-c("qseqid","binpath")
    lcahtf<-add.unknown.lca(lcahtf)
    mat<-do.call(rbind,stringr::str_split(lcahtf$binpath,";"))
    lcahtf<-as.data.frame(cbind(lcahtf$qseqid,mat[,1],mat[,2],mat[,3],mat[,4],mat[,5],mat[,6],mat[,7]))
    colnames(lcahtf)<-c("qseqid","K","P","C","O","F","G","S")
    
  } else {
    lcahtf<-data.frame(matrix(nrow=1,ncol = 8))
    colnames(lcahtf)<-c("qseqid","K","P","C","O","F","G","S")
  }
  
  rm(btabhtf)
  
  ###################################################
  #combine
  #combine
  sp_level<-lcasp[lcasp$S!="unknown",]
  g_level<-lcag[lcag$G!="unknown",]
  if(nrow(g_level)>0) g_level$S<-NA
  g_level<-g_level[!g_level$qseqid %in% sp_level$qseqid,]
  f_level<-lcaf[lcaf$F!="unknown",]
  if(nrow(f_level)>0) f_level$G<-NA
  if(nrow(f_level)>0) f_level$S<-NA
  f_level<-f_level[!f_level$qseqid %in% sp_level$qseqid,]
  f_level<-f_level[!f_level$qseqid %in% g_level$qseqid,]
  
  abs_level<-lcahtf
  if(nrow(abs_level)>0) abs_level$G<-NA
  if(nrow(abs_level)>0) abs_level$S<-NA
  if(nrow(abs_level)>0) abs_level$F<-NA
  abs_level<-abs_level[!abs_level$qseqid %in% sp_level$qseqid,]
  abs_level<-abs_level[!abs_level$qseqid %in% g_level$qseqid,]
  abs_level<-abs_level[!abs_level$qseqid %in% f_level$qseqid,]
  
  com_level<-rbind(sp_level,g_level,f_level,abs_level)
  com_level<-merge(x=qseqids, y = com_level, by = "qseqid",all.x = T)
  
  #info
  t2<-Sys.time()
  t3<-round(difftime(t2,t1,units = "mins"),digits = 2)
  
  write.table(x = com_level,file = out,sep="\t",quote = F,row.names = F)
  
  message(c("Complete. ",total_hits, " hits from ", total_queries," queries processed in ",t3," mins."))
  
  message("Note: If none of the hits for a BLAST query pass the binning thesholds, the results will be NA for all levels.
                 If the LCA for a query is above kingdom, e.g. cellular organisms or root, the results will be 'unknown' for all levels.
                 Queries that had no BLAST hits, or did not pass the filter.blast step will not appear in results.  ")
}

