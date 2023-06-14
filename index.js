const { app, BrowserWindow, dialog, ipcMain } = require('electron')
const path = require('path')
const fs = require('fs');
const fsex = require('fs-extra')
const { execSync, exec } = require('child_process');

const JULIA_PATH = `${app.getAppPath()}/Julia-1.8.5/bin/julia.exe`;
const PG_MAIN = `${app.getAppPath()}/ext/src/PathwayGrabber.jl`;
const PG_PATH = `"${JULIA_PATH}" "${PG_MAIN}"`;
var CURRENT_WORKING_DIRECTORY = "";
const TEST_WORKING_DIRECTORY = `${app.getAppPath().replace(/\\/g, "/")}/test`;

async function getTestInputFile() {
  return `${app.getAppPath()}/test/kegg-uniprot.xlsx`;
}

async function handleFileOpen() {
  const { canceled, filePaths } = await dialog.showOpenDialog()
  if (canceled) { } else {
    return filePaths[0]
  }
}

async function exportOutput(evt) {
  const { filePath } = await dialog.showSaveDialog( { defaultPath: `PathwayGrabber-${Date.now()}.zip` })
  if (filePath) {
    from = CURRENT_WORKING_DIRECTORY == "" ? TEST_WORKING_DIRECTORY + "/PathwayGrabber.zip" : CURRENT_WORKING_DIRECTORY + "/PathwayGrabber.zip";
    fsex.copy(from, filePath, { overwrite: true }, err => {
      if (err) return console.error(err);
      else exec("explorer /select, \""+filePath+"\" ");
    })
  }
}

function readTsvFile(file) {
  // console.log("Reading file "+file)
  content = [];
  let data = fs.readFileSync(file, 'utf8').split('&crlf;');
  // i = 0;
  data.forEach((row, index) => {
    if(row != "") content.push(row.split('\t'))
    // if(row != "") {
    //   cells = row.split('\t');
    //   cells.unshift(i++);
    //   content.push(cells);
    // }
  })
  // console.log(`-> The file contains ${content.length} rows and ${content[0].length} columns`)
  return content;
}

function handleSubmitButton(evt, settings) {
  // delete any previous temp dir
  if(CURRENT_WORKING_DIRECTORY != "") {
    console.log(`Previous working directory '${CURRENT_WORKING_DIRECTORY}' is getting deleted`);
    fsex.removeSync(CURRENT_WORKING_DIRECTORY);
    console.log("Directory has been deleted")
  }
  // format the settings
  [input, sheet, line, type, hasSite, content, idCol, siteCol, pvalCol, tukeyCol, fcCol, conds, pvalThreshold, tukeyThreshold, fcThreshold] = settings;
  // format the conditions eventually
  if (conds != "") conds = conds.replace(/\n/g, "__cn__");
  // create the command
  cmd = `${PG_PATH} "${input}" "${sheet}" "${line}" "${type}" "${hasSite}" "${content}" "${idCol}" "${siteCol}" "${pvalCol}" "${tukeyCol}" "${fcCol}" "${conds}" "${pvalThreshold}" "${tukeyThreshold}" "${fcThreshold}"`;
  // run the command and deal with the output
  console.log(cmd)
  // TODO add a timer to count the time needed (just for the log)
  // TODO it would be nice to have the julia logs displayed in real time in the console
  const stdout = execSync(cmd)
  
  // get the path from the log
  outputPath = stdout.toString().replace(/[\s\S]*ENDOFPROCESS[^:]*: /, "").replace(/\\/g, "/").replace("\n", "");
  console.log("Output path is '"+outputPath+"'")

  // get the tsv files and load their content
  summary = readTsvFile(outputPath + "/Summary.tsv");
  entries = readTsvFile(outputPath + "/Entries.tsv");
  maps = readTsvFile(outputPath + "/Maps.tsv");

  // return the complete output
  CURRENT_WORKING_DIRECTORY = outputPath;
  return [outputPath, entries, maps, summary];
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fakeRun(evt) {
  // get the test tsv files and load their content
  summary = readTsvFile(TEST_WORKING_DIRECTORY + "/Summary.tsv");
  entries = readTsvFile(TEST_WORKING_DIRECTORY + "/Entries.tsv");
  maps = readTsvFile(TEST_WORKING_DIRECTORY + "/Maps.tsv");
  // await sleep(10000);
  return [TEST_WORKING_DIRECTORY, entries, maps, summary];
}

function getDimensions(evt, url) {
  w = "";
  h = "";
  let items = fs.readFileSync(url, 'utf8').replace(/[\s\S]*<img /, "").replace(/ src=[\s\S]*/, "").split(" ");
  for (let i = 0; i < items.length; i++) {
    if (items[i].startsWith("width=")) w = items[i].split("=")[1].replace(/[^0-9]/g, "");
    if (items[i].startsWith("height=")) h = items[i].split("=")[1].replace(/[^0-9]/g, "");
  }
  // console.log("Width: '" + w + "' ; Height: '" + h + "'")
  return [w, h];
}

const createWindow = () => {
  const mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    autoHideMenuBar: true,
    icon: path.join(__dirname, 'resources/icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    }
  })

  ipcMain.on('export-output', exportOutput)
  mainWindow.loadFile('index.html')
}

app.whenReady().then(() => {
  ipcMain.handle('test', getTestInputFile)
  ipcMain.handle('dialog:browseFile', handleFileOpen)
  ipcMain.handle('click-submit', handleSubmitButton)
  ipcMain.handle('get-dimensions', getDimensions)
  ipcMain.handle('fake-run', fakeRun)
  createWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if(CURRENT_WORKING_DIRECTORY != "") {
    console.log("Deleting directory now")
    fsex.removeSync(CURRENT_WORKING_DIRECTORY);
    console.log("Done.")
  }
  if (process.platform !== 'darwin') app.quit()
})
