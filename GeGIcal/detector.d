module dectector;

// this file is mostly notes for myself, but I did start writing an object thinking I may use it, but I am likely going to just keep putting notes here
/+
struct Detector{
    
    enum density = 5.32; // g/cm^^3

    enum Zeff = 32;

        // μeτ / μhτ = 0.72/0.84 (cm^^2/v)
        // Tau is charge carier lifetime

        // energy resolution at 140keV <1%
        // energy e-h pair 2.98 (eV)

        // fano factor F =0.15



    enum SETBACK_FROM_FRONT = 0.6;// cm
    enum DIAMETER = 9.0; // mm
    enum THICKNESS = 1.0; // mm

    // 16X16 STRIPS ORTHAGONAL (vertical/horizontal)

    static const uint nColumns = 16;
    static const uint nRows = 16;

    //Front/back?

    //SUB STRIP NOT RELIABLE W/ only one neighbor
    enum stripPitch = 0.5; //cm
    enum stripWidth = 4.75; //mm
    enum gapWidth = stripPitch - stripWidth; // 0.25 mm

    // total active area 55.1 cm^2

    static const double temperture = 83; // k
    static const double potential = -700; //V

    static const auto ADC = struct {
        const uint bitWidth = 12;
        const double clockSpeed = 50.0 * 10^^6; // 50Mhz
        const double clockTick = 1.0/clockSpeed; // 20ns
    }

    // triggers when fast signal > approx 18keV

    // 50% gotnhath ycaghiot amplitude for DOI
    // 55.4% intrinsic efficiency
    // Imager32 estimates depth  of  interaction  by  dividing into  1‐mm‐thick  depth bins based on the 50% CFD time differences between the collecting strips on the front and back of the detecto

    // can recod approx 450000 cps

    // something about flood image - histogram
    // new events .53x.53 mm

    // todo LOAD LOOKUP TABLE FILE
    

    //


    // front positive amplitudes back neg lindsy


    /*
    rose: 
        For the DCCoupled side (which predicts the x-position, and are the vertical front strips),
        spatial resolution is poor at depth 5 (see Figures 3.5 and 3.2
        Likewise, the CR Lower Bound for depth 5 on the DC-Coupled side is larger than the other depths.
        This also occurs on the AC-Coupled side for depths 8 and 9 (which corresponds to the y-positioning).
 
    
    the detector is reverse-biased, the AC-coupled side collects the electrons and the DC-coupled side collects the holes, one reason for this behavior is that the electrodes are more sensitive as their respective charge carriers get closer.
    
    */

    /* 2013 settings
    MinDcChan                 = 0
    MaxDcChan                 = 15
    MinAcChan                 = 16
    MaxAcChan                 = 31
    
    */


    
}
+/

//ACMULt
//DCMULT

/+
///single knife edge pinhole
class pinhole{

    // Geometric (Rg) resolution
    // geometricResolution  = d(1+1/M)

    // Total Resolution
    // totalResolution = sqrt(geometricResolution^^2 + (Rd)/M)^^2)

    //sensitivity (η)
    // sensitivity = (d^^2)/(16*a^^2) * (cos(theta))^^3

    // a is distance from the columnator
    // theta is radius of rotation
}
+/

/+
%% Calculating energies from the Klein-Nishina and Compton Scattering Formulas

%Constants

photon_energy = 131; %keV

rest_energy = 511; %keV

alpha = photon_energy/rest_energy;

Z = 32; %For Ge

r_o_squared = (2.817*10^-20)^2; % classical electron radius in km

theta = (0:2:180)./(180/pi); %Scattering Angles converted to radians


%Get the distribution of the scattering angles for the listed photon energies:

for i = 1:length(theta)

angle_dist(1,i) = Z*r_o_squared*(1./(1+alpha*(1-cos(theta(i))))^2 .* ((1+(cos(theta(i)))^2)./2)*(1+ (alpha^2*(1-cos(theta(i)))^2)./((1+(cos(theta(i)))^2)*(1+alpha*(1-cos(theta(i)))))));

end




%Use Compton Formula to get range of energies:

for j = 1:length(angle_dist)

scatteredphoton_energy_UpperLimit(1,i) = photon_energy ./ (1+alpha*(1-cos(theta(j)+angle_dist(j))));

scatteredphoton_energy_LowerLimit(1,i) = photon_energy ./ (1+alpha*(1-cos(theta(j)-angle_dist(j))));


end


+/