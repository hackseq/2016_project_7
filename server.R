#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)

library(readr)
library(dplyr)
library(Matrix)
library(plotly)
library(magrittr)
library(DT)

source('difGenes.R')
print('starting server')

# Define server logic required to draw a histogram
shinyServer(function(input, output, session) {
  rValues = reactiveValues(selected_vector1 = NULL,
                           selected_vector2 = NULL,
                           tsne = tsne)

  #check if came from previous compare tab
  query_vals <- reactive({session$clientData$url_search
                                })

  observe({if ('?compare' == query_vals()){print(query_vals())
    updateTabsetPanel(session, inputId = 'main_panel', 'Explore clusters') }})


  output$tSNE_selectForRename = renderPlotly({
    plot_ly(rValues$tsne, x = ~tSNE_1, y = ~tSNE_2, text = ~barcode, color = ~id, key = ~barcode, source = 'selectForRename') %>%
      layout(
        dragmode = "select",
        xaxis = list(title = tsne_xlab),
        yaxis = list(title = tsne_ylab)
      )
  })

  # main SNE plot ---------
  output$tSNEPlot <- renderPlotly({
    # size of the bins depend on the input 'bins'
    plot_ly(rValues$tsne, x = ~tSNE_1, y = ~tSNE_2, text = ~barcode, color = ~id, key = ~barcode, source= 'hede') %>%
      layout(
        dragmode = "select",
        xaxis = list(title = tsne_xlab),
        yaxis = list(title = tsne_ylab)
      )
  })

  # COMPARE TAB-------
  #render initial seleciton plot
  output$tSNE_select_one <- renderPlotly({
    # size of the bins depend on the input 'bins'
    plot_ly(rValues$tsne, x = ~tSNE_1, y = ~tSNE_2, text = ~barcode, color = ~id, key = ~barcode, source = "selection_plot_one") %>%
      layout(
        dragmode = "select",
        xaxis = list(title = tsne_xlab),
        yaxis = list(title = tsne_ylab)
      )
  })

  # selection code and differential expression ------
  selected_data <- reactive({event_data("plotly_selected", source = "selection_plot_one")})

  selected_data_toRename <- reactive({event_data("plotly_selected", source = "selectForRename")})

  selected_data_two <- reactive({event_data("plotly_selected", source = "selection_plot_two")})

  #shows the button when first population selected in plot
  observe({
    if((((is.null(selected_data()) | is.null(dim(selected_data()))) & !input$selectDefinedGroup) |
       input$selectDefinedGroup & length(input$whichGroups)==0) | !is.null(rValues$selected_vector1)){
      disable("pop_one_selected")
    } else{
      enable('pop_one_selected')
    }
  })

  observe({
  #hide button one and two on load
  disable(id="pop_one_selected")
  hide(id="pop_two_selected")
  #hide second plot on load
  hide(id="div_select_two")
  hide(id="comparisonOutput")
  hide(id = 'downloadDifGenes')
  hide(id="reload")
  })


  #if select new groups button is pressed reload page on this tab
  observeEvent(input$reload, {
    print("hello worlddd")
    js$refresh()
  })

  #render second selection plot when first population locked-in
  output$tSNE_select_two <- renderPlotly({
    input$pop_one_selected
    isolate( plot_ly(rValues$tsne, x = ~tSNE_1, y = ~tSNE_2, text = ~barcode, color = ~id, key = ~barcode, source = "selection_plot_two") %>%
      layout(
        dragmode = "select",
        xaxis = list(title = tsne_xlab),
        yaxis = list(title = tsne_ylab)
      ))
  })

  # when button one is clicked, update ui and assign cell population to var
  # and show button two
  observeEvent(input$pop_one_selected, {
    html(id = "select_text", "Please select second group, or 'Save group 2' to use the remaining cells as group 2")
    disable(id = "pop_one_selected")
    show(id= "div_select_two")
    show("pop_two_selected")
    hide(id="div_select_one")
  })

  # when button two is clicked, update ui and assign cell population to var
  observeEvent(input$pop_two_selected, {
    html(id = "select_text", "")
    disable(id = "pop_two_selected")
    show('comparisonOutput')
    show('histPlot')
    show("reload")
  })

  #output$newPlot <- renderPlotly({
   # input$pop_selected
    #new_tsne <- isolate(selected_data())
    #plot_ly(new_tsne, x = ~x, y = ~y, text = ~key) %>%
     # layout(dragmode = "select")})


  # code for setting the clusters -----

  observe({
    if(input$selectDefinedGroupForRename){
      show(id = 'whichGroupsForRename')
    } else{
      updateCheckboxGroupInput(session, inputId = 'whichGroupsForRename', choices = unique(rValues$tsne$id) %>% sort, selected = NULL)
      hide(id = 'whichGroupsForRename')
    }
  })

  observe({
    print(input$renamePoulationButton)
  })

  observe({
    if(input$renamePoulationButton>=1){
      isolate({
        if(!input$selectDefinedGroupForRename){
          tsneSubset = rValues$tsne[round(rValues$tsne$tSNE_1, 5) %in% round(selected_data_toRename()$x, 5) & round(rValues$tsne$tSNE_2, 5) %in% round(selected_data_toRename()$y, 5),]
          } else{
          tsneSubset = rValues$tsne[rValues$tsne$id %in% input$whichGroupsForRename,]
        }
        out = tsneSubset$barcode

        

        rValues$tsne[rValues$tsne$barcode %in% out,'id'] = input$newClusterName
        # update everything that uses old clusters
        updateCheckboxGroupInput(session,
                                 inputId = 'whichGroups',
                                  label = 'Predefined clusters:',
                                  choices = unique(rValues$tsne$id) %>% sort)
        updateCheckboxGroupInput(session,
                                 inputId = 'whichGroupsForRename',
                                 label = 'Predefined clusters:',
                                 choices = unique(rValues$tsne$id) %>% sort)
    })
    }
    })
  


  # do I want to select defined groups?------
  observe({
    if(input$selectDefinedGroup){
      show(id = 'whichGroups')
    } else{
      updateCheckboxGroupInput(session, inputId = 'whichGroups', choices = unique(rValues$tsne$id) %>% sort, selected = NULL)
      hide(id = 'whichGroups')
    }
  })

  observe({
    if(input$pop_one_selected==1){
      isolate({
        updateCheckboxInput(session, inputId = 'selectDefinedGroup',
                            value = F,
                            label = 'Select predefined cluster(s) for group 2')
        print('group1 selection attempt')
        if(!input$selectDefinedGroup){
          tsneSubset = rValues$tsne[rValues$tsne$tSNE_1 %in% selected_data()$x & rValues$tsne$tSNE_2 %in% selected_data()$y,]
        } else{
          tsneSubset = rValues$tsne[rValues$tsne$id %in% input$whichGroups,]
        }
        rValues$selected_vector1 = barcodes$Barcode %in% tsneSubset$barcode
      })
    }
  })

  observe({
    if(input$pop_two_selected == 1){
      hide('div_select_two')
      hide(id = 'definedInputSelection')
      isolate({
        if(!input$selectDefinedGroup){
          if(!is.null(selected_data_two())){
            tsneSubset = rValues$tsne[rValues$tsne$tSNE_1 %in% selected_data_two()$x & rValues$tsne$tSNE_2 %in% selected_data_two()$y,]
            out = barcodes$Barcode %in% tsneSubset$barcode
          } else {
            # if nothing is selected, select the negative set based on tsne
            out = barcodes$Barcode %in% rValues$tsne$barcode[!rValues$tsne$barcode %in% barcodes$Barcode[rValues$selected_vector1]]
          }
        } else{
          tsneSubset = rValues$tsne[rValues$tsne$id %in% input$whichGroups,]
          out = barcodes$Barcode %in% tsneSubset$barcode
        }
        rValues$selected_vector2 = out
      })
    }
  })

  second_clicked_eds <-reactive({input$pop_two_selected
    barcodes_1 <- barcodes$Barcode[isolate({rValues$selected_vector1})]
    barcodes_2<- barcodes$Barcode[isolate({rValues$selected_vector2})]
    # isn't this kinda cheating?? two groups can intersect
    g1 = rValues$tsne[ rValues$tsne$barcode %in% barcodes_1 & !(rValues$tsne$barcode %in% barcodes_2),]
    g2 = rValues$tsne[rValues$tsne$barcode %in% barcodes_2  & !(rValues$tsne$barcode %in% barcodes_1),]
    intersection = rValues$tsne[ rValues$tsne$barcode %in% barcodes_2 & rValues$tsne$barcode %in% barcodes_1 ,]
    list(g1, g2, intersection)})




  second_clicked <-reactive({input$pop_two_selected})



  # Once group 1 and group 2 of cells are selected,
  # create 10 boxplots showing the gene expression distributions
  # of group 1 and group 2 for the top 10 up-regulated and
  # top 10 down-regulated genes
  output$histPlot <- renderPlotly({
    if ( !is.null(differentiallyExpressed()) ) {
      # TODO: Allow user to specify this
      gene_cnt <- 10

      nbr_group1 <- sum(rValues$selected_vector1)
      nbr_group2 <- sum(rValues$selected_vector2)
      nbr_barcodes <- nbr_group1 + nbr_group2

      diff_genes <- differentiallyExpressed()$`Gene Symbol`
      if(is.null(input$difGeneTable_rows_selected)){
        gene_indices <- c(1:gene_cnt, (length(diff_genes)-gene_cnt+1):length(diff_genes))
      } else{
        gene_indices = input$difGeneTable_rows_selected
      }

      dg_mat <- c()
      for ( n in gene_indices ) {
        # Get gene expression data and shift/log2-transform
        gene_idx <- which(genes$Symbol == diff_genes[n])
        dat1 <- log2(expression[gene_idx, rValues$selected_vector1] + 0.1)
        dat2 <- log2(expression[gene_idx, rValues$selected_vector2] + 0.1)

        # Store data into matrix of size 'nbr_barcodes' rows by 4 cols
        dg_mat <- rbind(dg_mat,
                        data.frame(gene = rep(diff_genes[n], nbr_barcodes),
                                   expr = c(dat1, dat2),
                                   group = c(rep("1", nbr_group1),
                                             rep("2", nbr_group2)),
                                   panel = rep(n, nbr_barcodes)
                        )
        )
      }

      # Ensure that data type for each column is appropriate for ggplot display
      # TODO: Simplify this...
      dg_mat <-
        dg_mat %>% mutate(
          gene = as.character(gene),
          expr = as.numeric(expr),
          group = as.factor(group),
          panel = as.factor(panel)) %>%
        arrange(panel)

      # TODO: Find a better way to preserve gene order
      dg_mat$gene <- factor(dg_mat$gene, levels = dg_mat$gene)
      dimensions= ceiling(sqrt(length(dg_mat$gene %>% unique)))
      ggplot(dg_mat, aes(x=group, y=expr, fill=group)) + geom_boxplot() +
        labs(y="log2(gene expression + 0.1)", x="Group") +
        facet_wrap(~gene, scales="free_x", nrow=dimensions, ncol=dimensions) +
        theme(plot.margin = unit(c(0, 0, 0, 3), "lines"),
              panel.margin.y = unit(1, "lines"),
              panel.margin.x = unit(0.5, "lines"),
              panel.background = element_rect(fill = "white"),
              strip.background = element_rect(fill = "white"),
              legend.position = "none")
      ggplotly()
    } else {
      plotly_empty()
    }
  })

  output$tSNE_summary <- renderPlotly({
    groups <- second_clicked_eds()
    g1 = groups[[1]]
    g2 = groups[[2]]
    intersection = groups[[3]]
    g1["group"] <- rep('group 1', dim(g1)[1])
    g2["group"] <- rep('group 2', dim(g2)[1])
    intersection["group"] <- rep('both', dim(intersection)[1])
    if (dim(intersection)[1] == 0){
      all_groups = rbind(g2, g1)
      colours = c("dark red", "dark blue")
    }
    else{
      all_groups = rbind(g2, intersection, g1)
      colours = c("purple", "dark red", "dark blue")
    }
    plot_ly(all_groups, x = ~tSNE_1, y = ~tSNE_2, text = ~barcode, color = ~group, colors = colours,
             key = ~barcode, source = "selection_plot_two") %>%
              layout(dragmode = "select",
                     xaxis = list(range = c(-40,40), title=tsne_xlab),
                     yaxis = list(range = c(-40,40), title=tsne_ylab)
                     )
    })

  # histogram of cells -----------
  output$cell_type_summary <- renderPlotly({
    tsne_id <- table(rValues$tsne$id)
    categories<- dim(tsne_id)
    #make dummy array of all types of tsne clusters so that tables() returns an entry for each type
    dummy = data.frame(rep('AAAAAAAAAAAA', length(categories)), rep(1.0, length(categories)), rep(1.0, length(categories)), names(tsne_id))
    names(dummy) = names(rValues$tsne[c('barcode','tSNE_1',	'tSNE_2','id' )])
    groups <- second_clicked_eds()
    g1 <-  rbind(groups[[1]][c('barcode','tSNE_1',	'tSNE_2','id' )], dummy)
    g2 <-  rbind(groups[[2]][c('barcode','tSNE_1',	'tSNE_2','id' )], dummy)
    intersection <- rbind(groups[[3]][c('barcode','tSNE_1',	'tSNE_2','id' )], dummy)
    #subtract 1 because we added an extra entry of each type in dummy array
    #also need to add the intersection back into groups because they were taken out in second_clicked_eds
    intersection_counts <- table(intersection$id) - 1
    g1_cell_counts<-table(g1$id) - 1 + intersection_counts
    g2_cell_counts<-table(g2$id) - 1 + intersection_counts
    cell_names <- names(g1_cell_counts)
    data <- as.data.frame(rbind(g1_cell_counts, g2_cell_counts))
    plot_ly(data, x=cell_names, y=~g1_cell_counts, marker = list(color = 'rgb(140,0,0)'), type='bar', name = 'group 1') %>%
      add_trace(y=~g2_cell_counts, marker = list(color = 'rgb(0,0,140)'), name = "group 2") %>%
      layout( yaxis = list(title = 'Count'), barmode = 'group')
  })



  output$downloadDifGenes = downloadHandler(
    filename = 'difGenes.tsv',
    content = function(file) {
      write_tsv(differentiallyExpressed(), file)
    })


  differentiallyExpressed = reactive({
    print('should I calculate dif genes?')
      print('yeah I guess')
      if(!is.null(rValues$selected_vector2) & !is.null(rValues$selected_vector1)){
        show('downloadDifGenes')
        difGenes(group1 = isolate(rValues$selected_vector1),
                 group2 = rValues$selected_vector2)
      }
  })


  output$difGeneTable = renderDataTable({
    if(!is.null(differentiallyExpressed())){
      table = differentiallyExpressed()
      table %<>% mutate(`Fold change` = format(`Fold change`, digits=3, scientific=FALSE)) %>%
        mutate(`Group 1 expression` = format(`Group 1 expression`, digits=3, scientific=FALSE)) %>%
        mutate(`Group 2 expression` = format(`Group 2 expression`, digits=3, scientific=FALSE))
      datatable(table,selection = 'multiple')
    }
  })
  # if a gene is selected from the data table, select that gene in the expression window
  observe({
    if(!is.null(input$difGeneTable_rows_selected)){
      gene = differentiallyExpressed()[input$difGeneTable_rows_selected,]$`Gene Symbol`
      selectedGene = list_of_genesymbols[grepl(regexMerge(paste0('^',gene,'_')),list_of_genesymbols)]
      updateSelectInput(session, 'input_genes', selected = selectedGene)
    }
  })



  # histogram of cells -----------
  # output$countPerCluster <- renderPlotly({
  #   ax <- list(
  #     title = "",
  #     zeroline = FALSE,
  #     showline = FALSE,
  #     showticklabels = FALSE,
  #     showgrid = FALSE
  #   )
  #   NumCells<-table(rValues$tsne$id)
  #   NumCells<-as.data.frame(NumCells)
  #   plot_ly(NumCells, x=~Var1, y=~Freq, color=~Var1, type='bar') %>%
  #     layout(xaxis = ax,
  #            yaxis = list(title = "Number of cells"))
  # })

  # plotting selected genes ----------
  # disable button when empty
  observe({
    if(length(input$input_genes)==0 ){
      disable('exprGeneButton')
    }else{
      enable('exprGeneButton')
    }
  })

  geneExpr_genes <- reactive({
    # Take a dependency on input$goButton
    input$exprGeneButton
    input$difGeneTable_rows_selected
    print('drawing gene plots')

    isolate(input$input_genes)
    })
  output$geneExprPlot <- renderUI({
    plot_output_list <- lapply(1:length(geneExpr_genes()), function(i) {
      plotname <- paste("plot", i, sep="")
      plotlyOutput(plotname)
    })
    # Convert the list to a tagList - this is necessary for the list of items
    # to display properly.
    do.call(tagList, plot_output_list)
  })

  observe({
    if(!input$exprVis == 'tSNE'){
      hide('tsneHeatmapOptions')
    } else{
      show('tsneHeatmapOptions')
    }
  })

  # Call renderPlot for each one. Plots are only actually generated when they
  # are visible on the web page.
  for (i in 1:geneExpr_maxItems) {
    # Need local so that each item gets its own number. Without it, the value
    # of i in the renderPlot() will be the same across all instances, because
    # of when the expression is evaluated.
    local({
      my_i <- i
      plotname <- paste("plot", my_i, sep="")

      output[[plotname]] <- renderPlotly({
        gene_of_interest <- parse_gene_input(geneExpr_genes()[my_i])
        gene_name <- parse_gene_input(geneExpr_genes()[my_i], get="name")
        plot_geneExpr(gene_of_interest, gene_name,
                      value_rangemid=input$Midpoint,
                      value_min = input$MinMax[1],
                      value_max = input$MinMax[2],
                      color_low = input$colmin,
                      color_mid = input$colmid,
                      color_high = input$colmax)
      })
    })
  }

  output$geneExprGeneCluster <- renderPlotly({
    gene_of_interest <- parse_gene_input(geneExpr_genes())
    gene_name <- parse_gene_input(geneExpr_genes(), get="name")
    plot_geneExprGeneCluster(gene_of_interest, gene_name,tsne = rValues$tsne)
  })
  
  
  #upload file page
  observeEvent(input$upload_button,{
    print("hello")
    barcodes_file <- input$barcodes_file
    genes_file <- input$genes_file
    tsne_file <- input$tsne_file
    mtx_file <- input$mtx_file
    if (is.null(barcodes_file) || is.null(genes_file) || is.null(tsne_file) || is.null(mtx_file)){
      print("missing file detected")
      print(is.null(barcodes_file))
      print(is.null(genes_file))
      print(is.null(tsne_file))
      print(is.null(mtx_file))
      
      return(NULL)
    }
    else{
      barcodes = read_tsv(barcodes_file$datapath, col_names = 'Barcode')
      genes = read_tsv(genes_file$datapath, col_names = c('ID','Symbol'))
      tsne = read_tsv(tsne_file$datapath, skip= 1,
                      col_name = c('barcode','tSNE_1', 'tSNE_2','cluster_id', 'id'),
                      col_types = cols(id = col_character())
      )
      expression = readMM(mtx_file$datapath)
      rownames(expression) = genes$ID
      colnames(expression) = barcodes$Barcode
      print('data reading complete')
      updateTabsetPanel(session, inputId = 'main_panel', 'Summary')
      
    }
    
    
  })


}
)
