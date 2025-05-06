function setAxesPadding(~,hax,padding)

unitsParent         = hax.Parent.Units;
hax.Parent.Units	= hax.Units;
op  = [[1 1].*padding hax.Parent.Position(3:4)-2*padding];
ti  = hax.TightInset;
hax.Position        = ...
    [op(1:2)+ti(1:2) op(3)-ti(1)-ti(3) op(4)-ti(2)-ti(4)];
hax.Parent.Units    = unitsParent;