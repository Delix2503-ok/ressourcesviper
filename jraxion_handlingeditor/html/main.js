const modals = {
    openhandlingModal: false,
};
      
async function closeNUI() {
    openhandlingModal.hide();
    await fetch(`https://jraxion_handlingeditor/close`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json; charset=UTF-8",
        },
    });
}

function handleUIMessage(data) {
    switch (data.type) {
        case "openHandlingEditor":
        openEditor(data);
        break;
        default:
        console.log("No action received.");
    }
}

function main() {
    window.addEventListener("message", (event) => handleUIMessage(event.data));
    openhandlingModal = new bootstrap.Modal(document.getElementById("open-handling-modal"));

    document.querySelectorAll(".modal").forEach((modal) => {
        modal.addEventListener("hidden.bs.modal", closeNUI);
    });  
}

main();
  
document.addEventListener('keydown', function(event) {
    if (event.key === "Escape") {
        closeNUI();
    }
});

function updateValue(input, change, key) {
    let currentValue;
    let newValue;
    
    if (input.dataset.type === "string") {
        currentValue = input.value;
        newValue = currentValue;
    } else {
        currentValue = parseFloat(input.value) || 0;
        newValue = currentValue + change;
        
        const min = parseFloat(input.dataset.min);
        const max = parseFloat(input.dataset.max);
        
        newValue = Math.max(min, Math.min(max, newValue));
        
        if (input.dataset.type === "int") {
            newValue = Math.round(newValue);
        } else if (input.dataset.type === "float") {
            newValue = parseFloat(newValue.toFixed(6)); 
        }
    }
    
    input.value = newValue;
    
    const slider = input.parentElement.querySelector('input[type="range"]');
    if (slider) {
        slider.value = newValue;
    }
    
    $.post('https://jraxion_handlingeditor/updateHandling', JSON.stringify({
        key: key,
        value: newValue
    }));
}

function updateFlag(checkbox, flagType) {
    const dropdownMenu = checkbox.closest('.dropdown-menu');
    const allFlags = Array.from(dropdownMenu.querySelectorAll('input[type="checkbox"]'));
    
    const flagValue = allFlags.reduce((acc, flag, index) => {
        return acc + (flag.checked ? Math.pow(2, index) : 0);
    }, 0).toString(16).toUpperCase();

    $.post('https://jraxion_handlingeditor/updateHandling', JSON.stringify({
        key: flagType,
        value: flagValue
    }));

    const input = dropdownMenu.parentElement.previousElementSibling.querySelector('input[type="text"]');
    input.value = flagValue;

    const selectedCount = allFlags.filter(f => f.checked).length;
    const dropdownButton = dropdownMenu.previousElementSibling;
    dropdownButton.textContent = `Selected Flags (${selectedCount})`;
}

function updateFromSlider(slider) {
    const input = slider.parentElement.querySelector('input[type="text"]');
    const key = input.dataset.handlingKey;
    const newValue = parseFloat(slider.value);
    
    if (input.dataset.type === "int") {
        input.value = Math.round(newValue);
    } else {
        input.value = parseFloat(newValue.toFixed(6));
    }
    
    $.post('https://jraxion_handlingeditor/updateHandling', JSON.stringify({
        key: key,
        value: input.value
    }));
}

function exportHandling() {
    const vehicleName = document.querySelector("#handlingLabel").innerHTML;
    const rows = document.getElementById('handling-data-accordion').getElementsByTagName('tr');
    
    const xmlHeader = '<?xml version="1.0" encoding="UTF-8"?>\n\n';
    const xmlStart = '<CHandlingDataMgr>\n  <HandlingData>\n    <Item type="CHandlingData">\n';
    const xmlEnd = '    </Item>\n  </HandlingData>\n</CHandlingDataMgr>';
    
    let xmlContent = `      <handlingName>${vehicleName}</handlingName>\n`;
    
    const handlingValues = {};
    
    Array.from(rows).forEach(row => {
        const input = row.querySelector('input[type="text"]');
        if (!input) return;
        
        const key = input.dataset.handlingKey;
        const value = input.value;
        
        switch(input.dataset.type) {
            case "float":
                handlingValues[key] = parseFloat(value).toFixed(6);
                break;
            case "int": 
                handlingValues[key] = Math.round(value);
                break;
            case "string":
                handlingValues[key] = value;
                break;
        }
    });
    
    handlingValues['vecCentreOfMassOffset'] = '0.000000 0.000000 0.000000';
    handlingValues['vecInertiaMultiplier'] = '1.000000 1.000000 1.000000';
    
    const propertyOrder = [
        'fMass', 'fInitialDragCoeff', 'fPercentSubmerged',
        'vecCentreOfMassOffset', 'vecInertiaMultiplier', 'fDriveBiasFront', 
        'nInitialDriveGears', 'fInitialDriveForce', 'fDriveInertia',
        'fClutchChangeRateScaleUpShift', 'fClutchChangeRateScaleDownShift',
        'fInitialDriveMaxFlatVel', 'fBrakeForce', 'fBrakeBiasFront',
        'fHandBrakeForce', 'fSteeringLock', 'fTractionCurveMax',
        'fTractionCurveMin', 'fTractionCurveLateral', 'fTractionSpringDeltaMax',
        'fLowSpeedTractionLossMult', 'fCamberStiffnesss', 'fTractionBiasFront',
        'fTractionLossMult', 'fSuspensionForce', 'fSuspensionCompDamp',
        'fSuspensionReboundDamp', 'fSuspensionUpperLimit', 'fSuspensionLowerLimit',
        'fSuspensionRaise', 'fSuspensionBiasFront', 'fAntiRollBarForce',
        'fAntiRollBarBiasFront', 'fRollCentreHeightFront', 'fRollCentreHeightRear',
        'fCollisionDamageMult', 'fWeaponDamageMult', 'fDeformationDamageMult',
        'fEngineDamageMult', 'fPetrolTankVolume', 'fOilVolume', 'fSeatOffsetDistX',
        'fSeatOffsetDistY', 'fSeatOffsetDistZ', 'nMonetaryValue', 'strModelFlags',
        'strHandlingFlags', 'strDamageFlags', 'AIHandling'
    ];
    
    propertyOrder.forEach(key => {
        if (handlingValues[key] !== undefined) {
            if (key.startsWith('vec')) {
                const [x, y, z] = handlingValues[key].split(' ');
                xmlContent += `      <${key} x="${x}" y="${y}" z="${z}" />\n`;
            } else if (key === 'strModelFlags' || key === 'strHandlingFlags' || key === 'strDamageFlags') {
                xmlContent += `      <${key}>${parseInt(handlingValues[key]).toString(16).toUpperCase()}</${key}>\n`;
            } else {
                xmlContent += `      <${key} value="${handlingValues[key]}" />\n`;
            }
        }
    });
    
    const subHandlingData = `      <SubHandlingData>
<Item type="" />
<Item type="" />
<Item type="" />
</SubHandlingData>\n`;
    
    const finalXml = xmlHeader + xmlStart + xmlContent + subHandlingData + xmlEnd;
    const exportArea = document.getElementById('exportArea');
    exportArea.value = finalXml;
    exportArea.style.display = 'block';
    exportArea.select();
    document.execCommand('copy');

    // Sauvegarder le fichier côté serveur (accessible via FTP)
    fetch(`https://${GetParentResourceName()}/saveHandling`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ vehicle: vehicleName, xml: finalXml })
    });
}

const flagDefinitions = {
    strModelFlags: [
        "IS_VAN", "IS_BUS", "IS_LOW", "IS_BIG", "ABS_STD", "ABS_OPTION", 
        "ABS_ALT_STD", "ABS_ALT_OPTION", "NO_DOORS", "TANDEM_SEATS",
        "SIT_IN_BOAT", "HAS_TRACKS", "NO_EXHAUST", "DOUBLE_EXHAUST",
        "NO1FPS_LOOK_BEHIND", "CAN_ENTER_IF_NO_DOOR", "AXLE_F_TORSION",
        "AXLE_F_SOLID", "AXLE_F_MCPHERSON", "ATTACH_PED_TO_BODYSHELL",
        "AXLE_R_TORSION", "AXLE_R_SOLID", "AXLE_R_MCPHERSON",
        "DONT_FORCE_GRND_CLEARANCE", "DONT_RENDER_STEER", "NO_WHEEL_BURST",
        "INDESTRUCTIBLE", "DOUBLE_FRONT_WHEELS", "FORCE_FRONT_WHEEL_WIDTH",
        "FORCE_REAR_WHEEL_WIDTH"
    ],
    strHandlingFlags: [
        "SMOOTH_COMPRESN", "REDUCED_MOD_MASS", "DISTRIB_FRONT_MASS",
        "DISTRIB_REAR_MASS", "OFFROAD_ABILITY", "OFFROAD_ABILITY2",
        "HALOGEN_LIGHTS", "PROC_REARWHEEL_1ST", "USE_MAXSP_LIMIT",
        "LOW_RIDER", "STREET_RACER", "SWINGING_CHASSIS", "EXTREME_GRIP",
        "INCREASED_GRAVITY", "VERTICAL_FLIGHT_MODE", "DISABLE_GROUND_CLEARANCE",
        "RACING_HANDLING", "EMERGENCY_VEHICLE", "NO_HANDBRAKE",
        "CVT", "ALT_EXT_WHEEL_BOUNDS_BEH", "DONT_RAISE_BOUNDS_AT_SPEED",
        "NARROW_BOUNDS", "MEDIUM_BOUNDS", "WIDE_BOUNDS"
    ],
    strDamageFlags: [
        "DRIVER_SIDE_FRONT_DOOR", "DRIVER_SIDE_REAR_DOOR", "DRIVER_PASSENGER_SIDE_FRONT_DOOR",
        "DRIVER_PASSENGER_SIDE_REAR_DOOR", "BONNET", "BOOT", "DRIVER_SIDE_FRONT_WINDOW",
        "DRIVER_SIDE_REAR_WINDOW", "PASSENGER_SIDE_FRONT_WINDOW", "PASSENGER_SIDE_REAR_WINDOW",
        "WINDSCREEN", "ENGINE", "ALL_WHEELS", "PETROL_TANK", "DOORS", "TRUNK", "WINDOWS",
        "ALL_PANELS", "WHEELS", "EXHAUST", "RADIATOR", "SUSPENSION", "BRAKES", "GEARBOX",
        "STEERING", "HEADLIGHTS", "TAILLIGHTS", "INDICATORS", "WIPERS", "MIRRORS"
    ]
};

function openEditor(data) {
    document.querySelector("#handlingLabel").innerHTML = data.vehicleName;
    let accordionContent = "";

    const sortedEntries = Object.entries(data.data).sort((a, b) => a[0].localeCompare(b[0]));

    for (let [i, dd] of sortedEntries) {
        if (i.startsWith('vec')) {
            continue;
        }
        
        const isNumeric = dd.type === "float" || dd.type === "int";
        const isFlag = i === "strModelFlags" || i === "strHandlingFlags" || i === "strDamageFlags";
        
        accordionContent += `
            <tr>
                <td>${dd.name}  
                    <button type="button" class="btn btn-secondary" data-bs-toggle="tooltip" data-bs-placement="top" data-bs-title="${dd.description}">
                        i
                    </button>
                    ${isNumeric ? `<small class="d-block text-muted">Min: ${dd.min} | Max: ${dd.max}</small>` : ''}
                </td>
                <td>${data.originalvalues[i]}</td>
                <td>
                    <div class="input-group">
                        ${isNumeric ? `<button class="btn btn-outline-secondary" type="button" onclick="updateValue(this.parentElement.querySelector('input[type=text]'), -${dd.change}, '${i}')">-</button>` : ''}
                        <input type="text" 
                            class="form-control" 
                            value="${data.values[i]}"
                            data-min="${dd.min || 0}"
                            data-max="${dd.max || 0}"
                            data-type="${dd.type}"
                            data-handling-key="${i}"
                            onchange="updateValue(this, 0, '${i}')"
                        >
                        ${isNumeric ? `<button class="btn btn-outline-secondary" type="button" onclick="updateValue(this.parentElement.querySelector('input[type=text]'), ${dd.change}, '${i}')">+</button>` : ''}
                        ${isNumeric && !isFlag ? `
                            <input type="range"
                                class="form-range" 
                                min="${dd.min}"
                                max="${dd.max}"
                                step="${dd.type === 'int' ? '1' : '0.000001'}"
                                value="${data.values[i]}"
                                oninput="updateFromSlider(this)"
                            >
                        ` : ''}
                    </div>
                    ${isFlag ? `
                        <div class="flag-dropdown dropdown">
                            <button class="btn dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                                Selected Flags (${(parseInt(data.values[i], 16).toString(2).match(/1/g) || []).length})
                            </button>
                            <div class="dropdown-menu">
                                ${flagDefinitions[i].map((flag, index) => `
                                    <div class="dropdown-item">
                                        <input type="checkbox" 
                                            id="${i}_${index}"
                                            ${(parseInt(data.values[i], 16) & (1 << index)) ? 'checked' : ''}
                                            onchange="updateFlag(this, '${i}')"
                                        >
                                        <label for="${i}_${index}">${flag}</label>
                                    </div>
                                `).join('')}
                            </div>
                        </div>
                    ` : ''}
                </td>
            </tr>
        `;
    }    
    
    document.querySelector("#handling-data-accordion").innerHTML = accordionContent;

    openhandlingModal.show();
    const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));
}

function searchVehicles() {
    const searchInput = document.getElementById('searchBar').value.toLowerCase();
    const rows = document.getElementById('handling-data-accordion').getElementsByTagName('tr');

    for (let row of rows) {
        const vehicleName = row.getElementsByTagName('td')[0].textContent.toLowerCase();
        if (vehicleName.includes(searchInput)) {
            row.style.display = '';
        } else {
            row.style.display = 'none';
        }
    }
}
