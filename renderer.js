// get items
const html = document.getElementsByTagName('html')[0];
const progress = document.getElementById('progress');
const inputFile = document.getElementById('input-file');
const btnBrowse = document.getElementById('btn-browse');
const sheetNumber = document.getElementById('sheet-number');
const headerLine = document.getElementById('header-line');
const inputType = document.getElementById('input-type');
const hasSite = document.getElementById('has-site');
const inputContent = document.getElementById('input-content');
const idCol = document.getElementById('id-col');
const siteCol = document.getElementById('site-col');
const pvalCol = document.getElementById('pval-col');
const tukeyCol = document.getElementById('tukey-col');
const fcCol = document.getElementById('fc-col');
const conditions = document.getElementById('conditions');
const pvalThreshold = document.getElementById('pval-threshold');
const tukeyThreshold = document.getElementById('tukey-threshold');
const fcThreshold = document.getElementById('fc-threshold');
const btnSubmit = document.getElementById('btn-submit');
const btnReset = document.getElementById('btn-reset');
const tblEntries = document.getElementById('tbl-entries');
const tblMaps = document.getElementById('tbl-maps');
const localHtml = document.getElementById('local-html');
const tblAbout = document.getElementById('tbl-about');
const tabs = document.getElementsByClassName('tab')[0].children;
const btnExport = document.getElementById('btn-export');

function openTab(evt, tabName) {
  // Declare all variables
  var i, tabcontent, tablinks;

  // Get all elements with class="tabcontent" and hide them
  tabcontent = document.getElementsByClassName("tabcontent");
  for (i = 0; i < tabcontent.length; i++) {
    tabcontent[i].style.display = "none";
  }

  // Get all elements with class="tablinks" and remove the class "active"
  tablinks = document.getElementsByClassName("tablinks");
  for (i = 0; i < tablinks.length; i++) {
    tablinks[i].className = tablinks[i].className.replace(" active", "");
  }

  // Show the current tab, and add an "active" class to the button that opened the tab
  document.getElementById(tabName).style.display = "block";
  evt.currentTarget.className += " active";
}

function getCurrentTabNumber() {
  current = 0;
  for(i = 0; i < tabs.length; i++) {
    if(tabs[i].className.includes('active')) current = i;
  }
  return current;
}

function goToPreviousTab(current) {
  current = getCurrentTabNumber();
  tabs[current == 0 ? tabs.length - 1 : current - 1].click();
}

function goToNextTab() {
  current = getCurrentTabNumber();
  tabs[current == tabs.length - 1 ? 0 : current + 1].click();
}

function show() {
  for (let i = 0; i < arguments.length; i++) {
    document.getElementById(arguments[i]).style.display = "table-row"
  }
}

function hide() {
  for (let i = 0; i < arguments.length; i++) {
    document.getElementById(arguments[i]).style.display = "none"
  }
}

function toggleShow(evt, target) {
  evt.currentTarget.checked ? show(target) : hide(target);
}

function toggleScores(evt, pvalue, tukey, fc, conds) {
  console.log(evt.currentTarget.value)
  value = evt.currentTarget.value
  if(value == 'none') {
    hide(pvalue, tukey, fc, conds)
  } else if(value == 'pvalue') {
    show(pvalue)
    hide(tukey, fc, conds)
  } else if(value == 'pvalue_fc') {
    show(pvalue, fc)
    hide(tukey, conds)
  } else {
    show(pvalue, tukey, fc, conds)
  }
}

function getIdentifierAnchors(data) {
  anchors = [];
  ids = data.toString().split(/[\n\s,]/);
  for (let i = 0; i < ids.length; i++) {
    if(ids[i] != "") {
      url = inputType.value == "kegg" ? "https://www.kegg.jp/entry/" + ids[i] : "https://www.uniprot.org/uniprotkb/" + ids[i];
      // on click, the content of the url is displayed
      anchors.push("<a onclick='fillHtml(\"" + url + "\")'>" + ids[i] + "</a>")
    }
  }
  return anchors.join(" ");
}

function getPathwayAnchors(data, path) {
  anchors = [];
  maps = data.toString().split("\n");
  for (let i = 0; i < maps.length; i++) {
    if(maps[i] != "") {
      items = maps[i].split(":");
      text = items.shift();
      // on click, the content of the html file is displayed
      anchors.push("<a title='" + items.join(" - ") + "' onclick='fillHtml(\"" + path + "/" + text + ".html\")'>" + text + "</a>")
    }
  }
  return anchors.join(" ");
}

function getStatusStyle(value) {
  css = "";
  if(value == "Non significant") css = " class='ko'";
  else if(value == "Significant") css = " class='ok'";
  else if(value == "Upregulated") css = " class='up'";
  else if(value == "Downregulated") css = " class='do'";
  return css;
}

function fillEntries(path, data) {
  if(data.length == 0) { data = [["No data loaded yet."]]; }
  content = "";
  for (let row = 0; row < data.length; row++) {
    content += "<tr>";
    for (let col = 0; col < data[row].length; col++) {
      tag = row == 0 ? "th" : "td";
      css = "";
      cell = data[row][col];
      if(row > 0) {
        if(col == 0 || (col == 1 && data[0][1].includes("dentifier"))) {
          cell = getIdentifierAnchors(cell);
        } else if(col == data[row].length - 1) {
          cell = getPathwayAnchors(cell, path)
        }
        css = getStatusStyle(cell);
      }
      content += "<" + tag + css + ">" + cell + "</" + tag + ">";
    }
    content += "</tr>";
  }
  tblEntries.innerHTML = content;
}

function fillMaps(path, data) {
  if(data.length == 0) { data = [["No data loaded yet."]]; }
  content = "";
  for (let row = 0; row < data.length; row++) {
    content += "<tr>";
    for (let col = 0; col < data[row].length; col++) {
      tag = row == 0 ? "th" : "td";
      cell = data[row][col];
      if(row > 0) {
        if(col == 0) {
          cell = getPathwayAnchors(cell, path)
        } else if(col == data[row].length - 1) {
          cell = getIdentifierAnchors(cell);
        }
      }
      content += "<" + tag + ">" + cell + "</" + tag + ">";
    }
    content += "</tr>";
  }
  tblMaps.innerHTML = content;
}

function fillSummary(data) {
  if(data.length == 0) { data = [["No data loaded yet."]]; }
  content = "";
  for (let row = 0; row < data.length; row++) {
    content += "<tr>";
    for (let col = 0; col < data[row].length; col++) {
      value = data[row][col];
      css = getStatusStyle(value);
      content += "<td" + css + ">" + value + "</td>";
    }
    content += "</tr>";
  }
  tblAbout.innerHTML = content;
}

async function fillHtml(url) {
  if(url.startsWith("http")) {
    localHtml.style.width = "100%";
    localHtml.style.height = "100vh";
  } else {
    dims = await window.electronAPI.getDimensions(url);
    console.log("Dimensions: "+dims);
    localHtml.style.width = (parseInt(dims[0]) + 20) + "px";
    localHtml.style.height = (parseInt(dims[1]) + 20) + "px";
    console.log("iFrame width: "+localHtml.style.width);
    console.log("iFrame height: "+localHtml.style.height);
  }
  localHtml.src = url;
  document.getElementById("html-tab").click();
}

function showProgress() { html.className = "waiting"; progress.style.display = "block"; }
function hideProgress() { progress.style.display = "none"; html.className = ""; }
function toggleProgress() {
  if(progress.style.display == "none") showProgress(); else hideProgress();
}

function initialize() {
  inputFile.value = "";
  sheetNumber.value = 1;
  headerLine.value = 1;
  inputType.value = "uniprot";
  hasSite.checked = false;
  inputContent.value = "pvalue";
  idCol.value = "A";
  siteCol.value = "";
  pvalCol.value = "B";
  tukeyCol.value = "";
  fcCol.value = "";
  conditions.value = "";
  pvalThreshold.value = 0.05;
  tukeyThreshold.value = 0.05;
  fcThreshold.value = 1.5;
  fillEntries("", []);
  fillMaps("", []);
  fillSummary([]);
  document.getElementById("settings-tab").click();
  document.getElementById("p-site-col").style.display = "none";
  show("p-pval-col");
  hide("p-tukey-col", "p-fc-col", "p-conds");
  localHtml.src = "";
  btnExport.style.opacity = 0;
}

// add listeners and callbacks
btnBrowse.addEventListener('click', async () => {
  const filePath = await window.electronAPI.browseFile();
  inputFile.value = filePath;
})

btnExport.addEventListener('click', async () => {
  await window.electronAPI.exportOutput();
})

btnSubmit.addEventListener('click', async () => {
  showProgress();
  
  const settings = [ inputFile.value, sheetNumber.value, headerLine.value, inputType.value, 
    hasSite.checked, inputContent.value, idCol.value, siteCol.value, pvalCol.value, tukeyCol.value, fcCol.value,  conditions.value, 
    pvalThreshold.value, tukeyThreshold.value, fcThreshold.value];
  const data = await window.electronAPI.clickSubmit(settings);

  fillEntries(data[0], data[1]);
  fillMaps(data[0], data[2]);
  fillSummary(data[3]);

  // await new Promise(r => setTimeout(r, 2000)); // only to simulate real computing
  hideProgress();
  btnExport.style.opacity = 100;
  document.getElementById("entries-tab").click();
});

btnReset.addEventListener('click', () => {
  initialize();
});

function keydownEvent(event) {
  if (event.key === 'Control' || event.key === 'Shift') return; // do nothing
  if(event.ctrlKey && ((!event.shiftKey && event.code === 'Tab') || event.code === 'PageDown')) goToNextTab();
  else if(event.ctrlKey && (event.shiftKey && event.code === 'Tab' || event.code === 'PageUp')) goToPreviousTab();
}

async function keyupEvent(event) {
  if(event.key == 't') { 
    // toggleProgress();
    // inputFile.value = "D:/workspace/LSMBO/JuliaxyTools/test_data/kegg-uniprot.xlsx";
    inputFile.value = await window.electronAPI.getTestInputFile();
    inputContent.value = "conditions";
    show("p-pval-col", "p-tukey-col", "p-fc-col", "p-conds");
    idCol.value = "B";
    pvalCol.value = "C";
    tukeyCol.value = "D";
    fcCol.value = "E";
  }
}

window.addEventListener('keydown', keydownEvent, true)
window.addEventListener('keyup', keyupEvent, true)

// initialize with default values
initialize();
