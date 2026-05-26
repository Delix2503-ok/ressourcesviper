# Attributions

> **Community Bridge** incorporates code from several outstanding libraries and resources, all licensed under GPLv3. We’re grateful to the talented developers who made their work available to the community.

---

## Libraries & Resources

<details>
<summary><strong>r_bridge</strong></summary>

**Purpose:** Code for codem-inventory bridging, and initial targeting  
**Repository:** [r_bridge](https://github.com/rumaier/r_bridge)

**Code we use:**

- Inventory bridging code for codem-inventory integration  
- Targeting system foundation

**Modifications made:**

- Adapted inventory bridge for codem compatibility in alternative structure

</details>

---

<details>
<summary><strong>ox_lib</strong></summary>

**Purpose:** Architectural inspiration  
**Repository:** [ox_lib](https://github.com/overextended/ox_lib)

**Compatibility features:**

- External resource integration for raycasting utilities  
- Shared conventions

**Implementation approach:**

- No direct code usage — maintains compatibility as external resource  
- Follows ox_lib conventions for seamless integration  
- Provides bridge compatibility for servers using ox_lib ecosystem

</details>

---

<details>
<summary><strong>renewed_lib</strong></summary>

**Purpose:** Object placer functionality  
**Repository:** [renewed_lib](https://github.com/Renewed-Scripts/Renewed-Lib)

**Code we use:**

- Object placement system

**Modifications made:**

- Updated variable naming for consistency  
- Added missing parameters for native functions  
- Updated deprecated ox_lib raycast camera export  
- Enhanced showtext UI to work with multiple systems  
- Moved placement text to locales for internationalization  
- Replaced ox_lib model request exports with our bridge functions

</details>

---

<details>
<summary><strong>duff</strong></summary>

**Purpose:** Version checker system and update notifications  
**Repository:** [duff](https://github.com/DonHulieo/duff/blob/d89ed3b0051194babf5711114a0c437d4e41f433/server/init.lua#L10C1-L28C4)

**Code we use:**

- Version checker formatting patterns  
- Repository information handling

**Modifications made:**

- Removed unnecessary variables  
- Enhanced to pull repository information from passed strings  
- Adapted print formatting for our use case

</details>

---

<details>
<summary><strong>Vehicle Properties System</strong></summary>

**Purpose:** Set and manage vehicle properties in the game world, inspired by multiple community frameworks.  
**Repositories referenced:**

- [ESX-Framework (ESX.Game.SetVehicleProperties)](https://github.com/esx-framework/es_extended)  
- [QB-Core (qb-core)](https://github.com/qbcore-framework/qb-core)  
- [ox_lib](https://github.com/overextended/ox_lib) (architectural inspiration and modifications)

**Code origin and inspiration:**

- Primarily draws on concepts and structures from ESX and QB-Core, with ox_lib serving as architectural inspiration.  
- ESX and QB-Core implementations use similar approaches for setting vehicle mods, colors, damages, and extras.  
- ox_lib adapts and extends these approaches within its framework, showing overlapping code patterns.

**Modifications made:**

- Combined and refactored logic to suit Community Bridge project needs.  
- Adapted license to GPLv3 for compatibility and open-source compliance.  
- Added explicit handling of custom colors, mod toggles, and damage states.

**Licensing notes:**

- Original ESX and QB-Core frameworks are GPLv3 licensed.  
- ox_lib is LGPL licensed, used here as architectural inspiration only.  
- This project’s vehicle properties code inherits GPLv3 licensing consistent with ESX/QB-Core, honoring their licensing terms and attributions.

</details>

---

## Special Thanks

A heartfelt thank you to all creators and maintainers of these libraries, bridges, and resources. Your dedication to open-source development and the FiveM community makes projects like Community Bridge possible.

Your willingness to share knowledge and code under GPLv3 licensing enables the entire community to build better, more compatible systems together.

---

## License Compliance

All incorporated code maintains its original GPLv3 licensing. Community Bridge inherits this license to ensure continued open-source availability and community collaboration.

For detailed license information, see the [LICENSE](LICENSE) file in the project root.

---

> *"If I have seen further it is by standing on the shoulders of Giants."* – Isaac Newton
