from ipyleaflet import Map, Marker
center = (52.204793, 360.121558)

m = Map(center=center, zoom=15)

marker = Marker(location=center, draggable=False)
m.add(marker);

m