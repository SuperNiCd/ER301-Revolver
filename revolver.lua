-- GLOBALS: app, connect
local Class = require "Base.Class"
local Unit = require "Unit"
local PitchControl = require "Unit.ViewControl.PitchControl"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ModeSelect = require "Unit.MenuControl.ModeSelect"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local SamplePool = require "Sample.Pool"
local SamplePoolInterface = require "Sample.Pool.Interface"
local SlicingView = require "SlicingView"
local ply = app.SECTION_PLY

local Revolver = Class{}
Revolver:include(Unit)

function Revolver:init(args)
  args.title = "Revolver"
  args.mnemonic = "RV"
  args.version = 1
  args.enableVariableSpeed = true
  Unit.init(self,args)
end

function Revolver:onLoadGraph(pUnit,channelCount)

    app.log("Hello from the onLoadGraph function of Revolver.")
    local tune = self:createObject("ConstantOffset","tune")
    local tuneRange = self:createObject("MinMax","tuneRange")
    local edge = self:createObject("Comparator","edge")
    edge:setTriggerMode()

    --temporarily adding a sin osc
    -- local f0 = self:createObject("GainBias","f0")
    -- local f0Range = self:createObject("MinMax","f0Range")
    local sinosc = self:createObject("SineOscillator","sinosc")
    local f0 = self:createObject("Constant", "f0")
    f0:hardSet("Value", 130.8)


    -- temporarily connect the V/oct up to the sine osc v/o in
    connect(tune,"Out",tuneRange,"In")
    connect(tune,"Out",sinosc,"V/Oct")
    -- connect(f0,"Out",sinosc,"Fundamental")
    -- connect(f0,"Out",f0Range,"In")
    connect(f0,"Out",sinosc,"Fundamental")
    connect(sinosc,"Out",pUnit,"Out1")
    if channelCount > 1 then
      connect(sin,"Out",pUnit,"Out2")
    end

    self:addBranch("V/oct","V/Oct",tune,"In")
    self:addBranch("trig","Trigger",edge,"In")
    self:addBranch("f0","Fundamental",f0,"In")
end

-- Set up the local views.  Right now just V/oct and trig
local views = {
  expanded = {"tune", "trigger"},
  collapsed = {},
}

function Revolver:onLoadViews(objects,controls)

      controls.tune = PitchControl {
        button = "V/oct",
        branch = self:getBranch("V/Oct"),
        description = "V/oct",
        offset = objects.tune,
        range = objects.tuneRange
      }

      controls.trigger = Comparator {
        button = "trig",
        branch = self:getBranch("Trigger"),
        description = "Trigger",
        edge = objects.edge,
      }

      -- controls.freq = GainBias {
      --   button = "f0",
      --   description = "Fundamental",
      --   branch = self:getBranch("Fundamental"),
      --   gainbias = objects.f0,
      --   range = objects.f0Range,
      --   biasMap = Encoder.getMap("oscFreq"),
      --   biasUnits = app.unitHertz,
      --   initialBias = 27.5,
      --   gainMap = Encoder.getMap("freqGain"),
      --   scaling = app.octaveScaling
      -- }

  return views
end

-- These functions are required for selecting sample from the card or sample pool.
function Revolver:setSample(sample)
  if self.sample then
    self.sample:release()
    self.sample = nil
  end
  self.sample = sample
  if self.sample then
    self.sample:claim()
  end

  if self.channelCount==1 then
    if sample==nil or sample:getChannelCount()==0 then
      -- self.objects.bump1:setSample(nil, 0)
    elseif sample:getChannelCount()==1 then
      -- self.objects.bump1:setSample(sample.pSample, 0)
    else -- 2 or more channels
      -- self.objects.bump1:setSample(sample.pSample, 0)
    end
  else
    if sample==nil or sample:getChannelCount()==0 then
      -- self.objects.bump1:setSample(nil, 0)
      -- self.objects.bump2:setSample(nil, 0)
    elseif sample:getChannelCount()==1 then
      -- self.objects.bump1:setSample(sample.pSample, 0)
      -- self.objects.bump2:setSample(sample.pSample, 0)
    else -- 2 or more channels
      -- self.objects.bump1:setSample(sample.pSample, 0)
      -- self.objects.bump2:setSample(sample.pSample, 1)
    end
  end
  if self.sampleEditor then
    self.fakePlayHead:setSample(sample and sample.pSample)
    self.sampleEditor:setSample(sample)
  end
  self:notifyControls("setSample",sample)
end

function Revolver:showSampleEditor()
  if self.sample then
    if self.sampleEditor==nil then
      self.sampleEditor = SlicingView(self,true)
      self.fakePlayHead = app.PlayHead("fake")
      self.fakePlayHead:setSample(self.sample and self.sample.pSample)
      self.fakePlayHead:setSlices(self.sample and self.sample.slices.pSlices)
      self.sampleEditor:setPlayHead(self.fakePlayHead)
      self.sampleEditor:setSample(self.sample)
    end
    self.sampleEditor:activate()
  else
    local SystemGraphic = require "SystemGraphic"
    SystemGraphic.mainFlashMessage("You must first select a sample.")
  end
end

function Revolver:doDetachSample()
  local SystemGraphic = require "SystemGraphic"
  SystemGraphic.mainFlashMessage("Sample detached.")
  self:setSample()
end

function Revolver:doAttachSampleFromCard()
  local task = function(sample)
    if sample then
      local SystemGraphic = require "SystemGraphic"
      SystemGraphic.mainFlashMessage("Attached sample: %s",sample.name)
      self:setSample(sample)
    end
  end
  local Pool = require "Sample.Pool"
  Pool.chooseFileFromCard(self.loadInfo.id,task)
end

function Revolver:doAttachSampleFromPool()
  local chooser = SamplePoolInterface(self.loadInfo.id)
  chooser:setDefaultChannelCount(self.channelCount)
  chooser:highlight(self.sample)
  local task = function(sample)
    if sample then
      local SystemGraphic = require "SystemGraphic"
      SystemGraphic.mainFlashMessage("Attached sample: %s",sample.name)
      self:setSample(sample)
    end
  end
  chooser:subscribe("done",task)
  chooser:activate()
end

-- Set up the header menu for selecitng samples.
local menu = {
  "sampleHeader",
  "pool",
  "card",
  "detach",
  "edit",

  "infoHeader","rename","load","save"
}

function Revolver:onLoadMenu(objects,controls)
  controls.sampleHeader = MenuHeader {
    description = "Sample Menu"
  }

  controls.pool = Task {
    description = "Select from Card",
    task = function() self:doAttachSampleFromCard() end
  }

  controls.card = Task {
    description = "Select from Pool",
    task = function() self:doAttachSampleFromPool() end
  }

  controls.detach = Task {
    description = "Detach",
    task = function() self:doDetachSample() end
  }

  controls.edit = Task {
    description = "Edit Sample",
    task = function() self:showSampleEditor() end
  }

  local sub = {}
  if self.sample then
    sub[1] = {
      position = app.GRID5_LINE1,
      justify = app.justifyLeft,
      text = "Attached Sample:"
    }
    sub[2] = {
      position = app.GRID5_LINE2,
      justify = app.justifyLeft,
      text = "+ "..self.sample:getFilenameForDisplay(24)
    }
    sub[3] = {
      position = app.GRID5_LINE3,
      justify = app.justifyLeft,
      text = "+ "..self.sample:getDurationText()
    }
    sub[4] = {
      position = app.GRID5_LINE4,
      justify = app.justifyLeft,
      text = string.format("+ %s %s %s",self.sample:getChannelText(), self.sample:getSampleRateText(), self.sample:getMemorySizeText())
    }
  else
    sub[1] = {
      position = app.GRID5_LINE3,
      justify = app.justifyCenter,
      text = "No sample attached."
    }
  end

  return menu, sub
end

return Revolver
