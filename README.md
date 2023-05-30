# Pathway Grabber

This repository is dedicated to the portable version of Pathway Grabber, that contains a graphical user interface. Pathway Grabber has been developped with Julia 1.8.5 and the GUI with ElectronJS.
The CLI version of Pathway Grabber is in the ext/ subdirectory, it was originally written as a Galaxy tool.

# Introduction 

The Kyoto Encyclopedia of Genes and Genomes (KEGG) is a database resource for understanding high-level functions of biological systems from large-scale molecular datasets. It has been developed together with a collection of tools for mapping molecular objects to KEGG pathway maps by the Kanehisa Laboratories (www.kanehisa.jp/). However, the online mapping procedure may not be straightforward and may require several steps to obtain the desired information. We developed Pathway Grabber as an integrated tool to search the KEGG database on a high-throughput basis for large omics datasets, and to obtain a visualisation that takes into consideration the differential analysis statistics applied after quantitative LC-MS/MS analyses.
Methods 
Pathway Grabber was developed with Julia 1.8.5 and some Javascript. From an Excel file containing UniProt or KEGG identifiers and associated statistical scoring values, including as well p-values from single (e.g. t-tests) or multiple comparisons (e.g. Anova and post-hoc tests) and fold changes, and the definition by the user of thresholds for each parameter, proteins are categorized as “non-significant” or “significant” and the information “upregulated” or “downregulated” is kept. In parallel, KEGG annotations are downloaded for each protein, which allows proteins from the dataset to be distributed among Pathway maps. A cache mechanism has been added to reduce the amount of data transfer, hence making the tool faster and decreasing the impact on the bandwidth. Extracted data is provided in the form of an Excel file and a list of HTML files.

# Results 

Output HTML files correspond to all Kegg Pathway maps that contain at least one protein from the dataset. On these maps, the information that has been made available is highlighted using a colour code relative to the ‘statistical category’ (for any item of interest, whether it is, e.g., a module, a protein/gene, a compound, a relation). Additional details about statistical scoring is also given as tooltip text items. All the items in the HTML files are clickable and reroute the user to the corresponding KEGG entries, but these files can also be used completely offline, once they are generated they do not require an Internet connection anymore.
The ouput Excel file summarizes the whole information that is highlighted on maps, one sheet listing all the pathways associated with each with protein, another sheet listing all proteins associated to each revealed pathway.
Conclusions 
Pathway Grabber is a user-friendly tool for biologists and proteomists, helping them to get a comprehensive view of the molecular regulations from large lists of proteins, including the statistical metrics of differential analysis. Therefore, it allows to greatly accelerate omics data mining and it helps to nicely draw graphical representations of omics results (1, 2). Today, Pathway Grabber constitutes a solid basis for many future improvements (e.g. network analysis, extension to other resources like Reactome).

# References 

* Chazarin, B.; Benhaim-Delarbre, M.; Brun, C.; Anzeraey, A.; Bertile, F.; Terrien, J. Molecular Liver Fingerprint Reflects the Seasonal Physiology of the Grey Mouse Lemur (Microcebus murinus) during Winter. Int. J. Mol. Sci. 2022, 23, 4254. https://doi.org/10.3390/ijms23084254
* Tascher, G.; Burban, A.; Camus, S.; Plumel, M.; Chanon, S.; Le Guevel, R.; Shevchenko, V.; Van Dorsselaer, A.; Lefai, E.; Guguen-Guillouzo, C.; Bertile, F. In-Depth Proteome Analysis Highlights HepaRG Cells as a Versatile Cell System Surrogate for Primary Human Hepatocytes. Cells 2019, 8, 192. https://doi.org/10.3390/cells8020192
