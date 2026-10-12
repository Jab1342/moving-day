--!strict
-- Server creates these on the furniture's Root. Set ownership to CarrierA before
-- enabling constraints; never enable constraints on an anchored assembly.
-- CarrierA is always lead/owner. On lead drop, promote CarrierB to CarrierA.
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
