--!strict
-- Server creates these on the furniture's Root. Set ownership to CarrierA before
-- enabling constraints; never enable constraints on an anchored assembly.
-- CarrierA is always lead/owner. On lead drop, promote CarrierB to CarrierA.
-- LeadGrip is CarrierA's physical Grip1/Grip2 index (absent defaults to 1).
-- First carrier of a Two item may request either free physical grip and becomes A.
-- CarrierB takes the opposite physical grip; promotion flips LeadGrip, preserving
-- the promoted player's physical attachment. With no carriers, reset LeadGrip to 1.
-- SecondGrip/SecondGripRelay refer to the CarrierB role, not physical Grip2.
-- The owning client updates AlignPosition.Position / AlignOrientation.CFrame.
-- Dolly=true allows one player to carry a Two item at Config.DollySpeedScale.
return table.freeze({
	Root = "Root",
	Attachment = "CarryAttachment",
	AlignPosition = "CarryAlignPosition",
	AlignOrientation = "CarryAlignOrientation",
	PositionMode = "OneAttachment",
	OrientationMode = "OneAttachment",
})
