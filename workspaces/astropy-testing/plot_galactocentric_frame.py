"""Visualize Galactocentric coordinates and ring orbits.

Source: converted from workspaces/galactocentric-frame/galactocentric-frame.ipynb
Used by Positron release-screenshot tests as the "Welcome" hero shot for
https://positron.posit.co/.
"""

import astropy.coordinates as coord
import matplotlib.pyplot as plt
import numpy as np
from astropy import units as u


def plot_positions_and_velocities(gc_rings):
    fig, axes = plt.subplots(1, 2, figsize=(12, 6), dpi=200)
    axes[0].plot(gc_rings.x.T, gc_rings.y.T, marker="None", linewidth=3)
    axes[0].text(-8.0, 0, r"$\odot$", fontsize=20)
    axes[0].set_xlim(-30, 30)
    axes[0].set_ylim(-30, 30)
    axes[0].set_xlabel("$x$ [kpc]")
    axes[0].set_ylabel("$y$ [kpc]")
    axes[0].set_title("Positions")
    axes[1].plot(gc_rings.v_x.T, gc_rings.v_y.T, marker="None", linewidth=3)
    axes[1].set_xlim(-250, 250)
    axes[1].set_ylim(-250, 250)
    axes[1].set_xlabel(f"$v_x$ [{(u.km / u.s).to_string('latex_inline')}]")
    axes[1].set_ylabel(f"$v_y$ [{(u.km / u.s).to_string('latex_inline')}]")
    axes[1].set_title("Velocities")
    fig.tight_layout()


c1 = coord.SkyCoord(
    ra=89.014303 * u.degree,
    dec=13.924912 * u.degree,
    distance=(37.59 * u.mas).to(u.pc, u.parallax()),
    pm_ra_cosdec=372.72 * (u.mas / u.yr),
    pm_dec=-483.69 * (u.mas / u.yr),
    radial_velocity=0.37 * (u.km / u.s),
    frame="icrs",
)
gc1 = c1.transform_to(coord.Galactocentric)
print(gc1.v_x, gc1.v_y, gc1.v_z)


v_sun = [11.1, 244, 7.25] * (u.km / u.s)  # [vx, vy, vz]
gc_frame = coord.Galactocentric(
    galcen_distance=8 * u.kpc, galcen_v_sun=v_sun, z_sun=0 * u.pc
)
gc2 = c1.transform_to(gc_frame)
print(gc2.v_x, gc2.v_y, gc2.v_z)


galcen_distance = 8 * u.kpc
pm_gal_sgrA = [-6.379, -0.202] * (u.mas / u.yr)  # from Reid & Brunthaler 2004
vy, vz = -(galcen_distance * pm_gal_sgrA).to(u.km / u.s, u.dimensionless_angles())
vx = 11.1 * (u.km / u.s)
v_sun2 = u.Quantity([vx, vy, vz])  # List of Quantity -> a single Quantity
gc_frame2 = coord.Galactocentric(
    galcen_distance=galcen_distance, galcen_v_sun=v_sun2, z_sun=0 * u.pc
)
gc3 = c1.transform_to(gc_frame2)
print(gc3.v_x, gc3.v_y, gc3.v_z)


# Build a grid of circular orbits at different galactocentric radii.
ring_distances = np.arange(10, 26, 5) * u.kpc
circ_velocity = 220 * (u.km / u.s)
phi_grid = np.linspace(90, 270, 512) * u.degree  # grid of azimuths

ring_rep = coord.CylindricalRepresentation(
    rho=ring_distances[:, np.newaxis],
    phi=phi_grid[np.newaxis],
    z=np.zeros_like(ring_distances)[:, np.newaxis],
)
angular_velocity = (-circ_velocity / ring_distances).to(
    u.mas / u.yr, u.dimensionless_angles()
)
ring_dif = coord.CylindricalDifferential(
    d_rho=np.zeros(phi_grid.shape)[np.newaxis] * (u.km / u.s),
    d_phi=angular_velocity[:, np.newaxis],
    d_z=np.zeros(phi_grid.shape)[np.newaxis] * (u.km / u.s),
)
ring_rep = ring_rep.with_differentials(ring_dif)
gc_rings = coord.SkyCoord(ring_rep, frame=coord.Galactocentric)
plot_positions_and_velocities(gc_rings)


# Now we can transform to galactic coordinates and visualize the rings in
# observable coordinates
gal_rings = gc_rings.transform_to(coord.Galactic)

fig, ax = plt.subplots(1, 1, figsize=(8, 6), dpi=200)
for i in range(len(ring_distances)):
    ax.plot(
        gal_rings[i].l.degree,
        gal_rings[i].pm_l_cosb.value,
        label=str(ring_distances[i]),
        marker="None",
        linewidth=3,
    )

ax.set_xlim(360, 0)
ax.set_xlabel("$l$ [deg]")
ax.set_ylabel(rf'$\mu_l \, \cos b$ [{(u.mas/u.yr).to_string("latex_inline")}]')
ax.legend()
plt.show()
