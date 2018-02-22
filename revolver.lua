-- GLOBALS: app, connect
local Class = require "Base.Class"
local Unit = require "Unit"
local PitchControl = require "Unit.ViewControl.PitchControl"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local Revolver = Class{}
Revolver:include(Unit)

function Revolver:init(args)
  args.title = "Revolver"
  args.mnemonic = "RV"
  args.version = 1
  Unit.init(self,args)
end

function Revolver:onLoadGraph(pUnit,channelCount)

    local tune = self:createObject("ConstantOffset","tune")
    local tuneRange = self:createObject("MinMax","tuneRange")
    local edge = self:createObject("Comparator","edge")
    edge:setTriggerMode()

    self:addBranch("V/oct","V/Oct",tune,"In")
    self:addBranch("trig","Trigger",edge,"In")

end

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

  return views
end

return Revolver
