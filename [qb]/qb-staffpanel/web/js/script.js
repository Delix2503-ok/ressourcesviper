let currentSelectedPlayer = null
let currentSelectedBusiness = null
let playerListData = []
let businessListData = []

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    // Tab switching
    document.querySelectorAll('.menu-item').forEach(item => {
        item.addEventListener('click', function() {
            const tab = this.getAttribute('data-tab')
            switchTab(tab)
        })
    })
    
    // Close button
    document.getElementById('closeBtn').addEventListener('click', function() {
        fetch('https://qb-staffpanel/close', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' }
        })
    })
    
    // Player search
    document.getElementById('playerSearch').addEventListener('input', function(e) {
        filterPlayerList(e.target.value)
    })
    
    // Action buttons
    document.getElementById('giveMoneyBtn').addEventListener('click', function() {
        if (!currentSelectedPlayer) {
            alert('Please select a player first')
            return
        }
        document.getElementById('moneyModal').classList.add('active')
    })
    
    document.getElementById('giveJobBtn').addEventListener('click', function() {
        if (!currentSelectedPlayer) {
            alert('Please select a player first')
            return
        }
        document.getElementById('jobModal').classList.add('active')
    })
    
    document.getElementById('giveItemBtn').addEventListener('click', function() {
        if (!currentSelectedPlayer) {
            alert('Please select a player first')
            return
        }
        document.getElementById('itemModal').classList.add('active')
    })
    
    // Modal buttons
    setupModals()
    
    // Add business button
    document.getElementById('addBusinessBtn').addEventListener('click', function() {
        alert('Business creation will be implemented later')
    })
    
    // Listen for NUI messages
    window.addEventListener('message', function(event) {
        switch(event.data.action) {
            case 'open':
                document.querySelector('.container').style.display = 'flex'
                updateStaffInfo(event.data.data)
                break
            case 'close':
                document.querySelector('.container').style.display = 'none'
                break
            case 'updateDashboard':
                updateDashboard(event.data.data)
                break
            case 'updatePlayersList':
                updatePlayersList(event.data.data)
                break
            case 'updatePlayerDetails':
                updatePlayerDetails(event.data.data)
                break
            case 'updateBusinessesList':
                updateBusinessesList(event.data.data)
                break
            case 'updateBusinessDetails':
                updateBusinessDetails(event.data.data)
                break
        }
    })
})

// Switch between tabs
function switchTab(tabName) {
    // Update menu items
    document.querySelectorAll('.menu-item').forEach(item => {
        item.classList.remove('active')
        if (item.getAttribute('data-tab') === tabName) {
            item.classList.add('active')
        }
    })
    
    // Update content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active')
        if (content.id === tabName + 'Tab') {
            content.classList.add('active')
        }
    })
    
    // Notify client to load data
    fetch(`https://qb-staffpanel/changeTab`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ tab: tabName })
    })
}

// Update staff info in sidebar
function updateStaffInfo(data) {
    document.getElementById('staffName').textContent = data.staffName
    document.getElementById('staffRank').textContent = data.staffRank
}

// Update dashboard statistics
function updateDashboard(data) {
    document.getElementById('onlinePlayers').textContent = data.onlinePlayers
    document.getElementById('onlineStaff').textContent = data.onlineStaff
    document.getElementById('serverUptime').textContent = formatUptime(data.serverUptime)
}

// Format uptime seconds to readable format
function formatUptime(seconds) {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    return `${hours}h ${minutes}m ${secs}s`
}

// Update players list
function updatePlayersList(players) {
    playerListData = players
    const container = document.getElementById('playersList')
    container.innerHTML = ''
    
    players.forEach(player => {
        const playerElement = document.createElement('div')
        playerElement.className = 'player-item'
        playerElement.setAttribute('data-player-id', player.id)
        playerElement.innerHTML = `
            <div class="player-item-id">[${player.id}]</div>
            <div class="player-item-name">${player.name}</div>
        `
        
        playerElement.addEventListener('click', function() {
            document.querySelectorAll('.player-item').forEach(item => {
                item.classList.remove('selected')
            })
            this.classList.add('selected')
            currentSelectedPlayer = player.id
            fetch('https://qb-staffpanel/selectPlayer', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ playerId: player.id })
            })
        })
        
        container.appendChild(playerElement)
    })
}

// Filter players list
function filterPlayerList(searchTerm) {
    searchTerm = searchTerm.toLowerCase()
    document.querySelectorAll('.player-item').forEach(item => {
        const playerId = item.getAttribute('data-player-id')
        const playerText = item.textContent.toLowerCase()
        
        if (playerText.includes(searchTerm)) {
            item.style.display = 'block'
        } else {
            item.style.display = 'none'
        }
    })
}

// Update player details
function updatePlayerDetails(details) {
    if (!details) return
    
    // Update header
    const header = document.getElementById('playerHeader')
    header.innerHTML = `
        <div class="player-avatar">
            <i class="fas fa-user"></i>
        </div>
        <div class="player-basic-info">
            <h3>${details.firstName} ${details.lastName}</h3>
            <p>ID: ${details.id} | Group: ${details.group}</p>
        </div>
    `
    
    // Update info grid
    const infoGrid = document.getElementById('playerInfo')
    infoGrid.innerHTML = `
        <div class="info-item">
            <div class="info-label">Date of Birth</div>
            <div class="info-value">${details.dob}</div>
        </div>
        <div class="info-item">
            <div class="info-label">Nationality</div>
            <div class="info-value">${details.nationality}</div>
        </div>
        <div class="info-item">
            <div class="info-label">Last Login</div>
            <div class="info-value">${details.lastLogin}</div>
        </div>
        <div class="info-item">
            <div class="info-label">Cash</div>
            <div class="info-value">$${details.cash}</div>
        </div>
        <div class="info-item">
            <div class="info-label">Bank</div>
            <div class="info-value">$${details.bank}</div>
        </div>
        <div class="info-item">
            <div class="info-label">Crypto</div>
            <div class="info-value">$${details.crypto}</div>
        </div>
        <div class="info-item">
            <div class="info-label">Job 1</div>
            <div class="info-value">${details.job1}</div>
        </div>
        <div class="info-item">
            <div class="info-label">Job 2</div>
            <div class="info-value">${details.job2}</div>
        </div>
    `
}

// Update businesses list
function updateBusinessesList(businesses) {
    businessListData = businesses
    const container = document.getElementById('businessesList')
    container.innerHTML = ''
    
    businesses.forEach(business => {
        const businessElement = document.createElement('div')
        businessElement.className = 'business-item'
        businessElement.setAttribute('data-business-id', business.id)
        businessElement.innerHTML = `
            <div class="business-name">${business.name}</div>
            <div class="business-meta">
                <span>${business.employees} employees</span>
                <span>$${business.balance}</span>
            </div>
        `
        
        businessElement.addEventListener('click', function() {
            document.querySelectorAll('.business-item').forEach(item => {
                item.classList.remove('selected')
            })
            this.classList.add('selected')
            currentSelectedBusiness = business.id
            fetch('https://qb-staffpanel/selectBusiness', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ businessId: business.id })
            })
        })
        
        container.appendChild(businessElement)
    })
}

// Update business details
function updateBusinessDetails(details) {
    if (!details) return
    
    // Update header
    const header = document.getElementById('businessHeader')
    header.innerHTML = `
        <div class="business-logo">
            <i class="fas fa-building"></i>
        </div>
        <div class="business-basic-info">
            <h3>${details.name}</h3>
            <p>ID: ${details.id}</p>
        </div>
    `
    
    // Update stats
    const stats = document.getElementById('businessStats')
    stats.innerHTML = `
        <div class="stat-box">
            <div class="stat-box-value">${details.employees}</div>
            <div class="stat-box-label">Employees</div>
        </div>
        <div class="stat-box">
            <div class="stat-box-value">$${details.balance}</div>
            <div class="stat-box-label">Total Balance</div>
        </div>
        <div class="stat-box">
            <div class="stat-box-value">${details.recentMovements.length}</div>
            <div class="stat-box-label">Recent Moves</div>
        </div>
    `
    
    // Update history
    const history = document.getElementById('businessHistory')
    history.innerHTML = `
        <div class="history-item">
            <div class="history-item-label">Last Withdrawal</div>
            <div class="history-item-value">${details.lastWithdrawal}</div>
        </div>
        <div class="history-item">
            <div class="history-item-label">Last Deposit</div>
            <div class="history-item-value">${details.lastDeposit}</div>
        </div>
        <div class="history-item">
            <div class="history-item-label">Recent Activity</div>
            <div class="history-item-value">${details.recentMovements[0] ? details.recentMovements[0].type + ': $' + details.recentMovements[0].amount : 'None'}</div>
        </div>
    `
    
    // Update employees placeholder
    const employeesPlaceholder = document.querySelector('.employees-placeholder')
    if (details.employeeList && details.employeeList.length > 0) {
        employeesPlaceholder.innerHTML = `
            <table style="width:100%;color:#fff;">
                <tr>
                    <th>Name</th>
                    <th>Rank</th>
                </tr>
                ${details.employeeList.map(emp => `<tr><td>${emp.name}</td><td>${emp.rank}</td></tr>`).join('')}
            </table>
        `
    }
}

// Setup modal interactions
function setupModals() {
    // Money modal
    const moneyModal = document.getElementById('moneyModal')
    document.getElementById('cancelMoneyBtn').addEventListener('click', function() {
        moneyModal.classList.remove('active')
    })
    document.getElementById('confirmMoneyBtn').addEventListener('click', function() {
        const moneyType = document.getElementById('moneyTypeSelect').value
        const amount = parseInt(document.getElementById('moneyAmount').value)
        
        fetch('https://qb-staffpanel/giveMoney', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                targetId: currentSelectedPlayer,
                moneyType: moneyType,
                amount: amount
            })
        })
        
        moneyModal.classList.remove('active')
    })
    
    // Job modal
    const jobModal = document.getElementById('jobModal')
    document.getElementById('cancelJobBtn').addEventListener('click', function() {
        jobModal.classList.remove('active')
    })
    document.getElementById('confirmJobBtn').addEventListener('click', function() {
        const jobName = document.getElementById('jobNameInput').value
        const jobGrade = parseInt(document.getElementById('jobGradeInput').value)
        
        fetch('https://qb-staffpanel/giveJob', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                targetId: currentSelectedPlayer,
                jobName: jobName,
                jobGrade: jobGrade
            })
        })
        
        jobModal.classList.remove('active')
    })
    
    // Item modal
    const itemModal = document.getElementById('itemModal')
    document.getElementById('cancelItemBtn').addEventListener('click', function() {
        itemModal.classList.remove('active')
    })
    document.getElementById('confirmItemBtn').addEventListener('click', function() {
        const itemName = document.getElementById('itemNameInput').value
        const amount = parseInt(document.getElementById('itemAmountInput').value)
        
        fetch('https://qb-staffpanel/giveItem', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                targetId: currentSelectedPlayer,
                itemName: itemName,
                amount: amount
            })
        })
        
        itemModal.classList.remove('active')
    })
    
    // Close modals when clicking outside
    window.addEventListener('click', function(event) {
        if (event.target.classList.contains('modal')) {
            event.target.classList.remove('active')
        }
    })
}