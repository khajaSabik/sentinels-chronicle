// Configuration - Update these with your actual API endpoint
const API_BASE_URL = 'https://0a3ybz50wj.execute-api.us-east-1.amazonaws.com/prod/';
const STACK_NAME = 'sentinels-chronicle';

// Helper function to format date
function formatDate(dateString) {
    if (!dateString) return 'Unknown date';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
    });
}

// Helper function to get severity level
function getSeverityLevel(severity) {
    const num = parseFloat(severity);
    if (num >= 8) return { level: 'critical', label: '🔴 CRITICAL' };
    if (num >= 6) return { level: 'high', label: '🟠 HIGH' };
    if (num >= 4) return { level: 'medium', label: '🟡 MEDIUM' };
    if (num >= 1) return { level: 'low', label: '🟢 LOW' };
    return { level: 'none', label: '⚪ INFO' };
}

// Fetch chronicles from API
async function fetchChronicles() {
    try {
        // Try API endpoint first
        let response = await fetch(`${API_BASE_URL}/chronicles`);
        
        if (!response.ok) {
            // Fallback: Try direct DynamoDB via Lambda function URL
            console.log('API not available, trying Lambda function URL...');
            response = await fetch(`https://${STACK_NAME}-lambda-url.proxy`);
        }
        
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Error fetching chronicles:', error);
        // Return mock data for testing
        return getMockData();
    }
}

// Mock data for testing
function getMockData() {
    return {
        chronicles: [
            {
                finding_id: 'mock-1',
                created_at: new Date().toISOString(),
                severity: 8.0,
                title: 'The Watcher in the Dark',
                chronicle: 'A shadow moved across the network perimeter. The Sentinel observed as reconnaissance probes tested the boundaries of the domain. This was not an attack—yet.',
                region: 'us-east-1'
            },
            {
                finding_id: 'mock-2',
                created_at: new Date(Date.now() - 3600000).toISOString(),
                severity: 5.0,
                title: 'Echoes Across the Boundary',
                chronicle: 'Unusual activity patterns emerged from the depths of the security logs. The Sentinel noted the anomaly, marking it for future observation.',
                region: 'us-east-1'
            }
        ],
        style_memory: 'Measured, atmospheric, security-focused. Never glorify attackers.'
    };
}

// Render chronicles to the page
function renderChronicles(data) {
    const container = document.getElementById('chronicles-container');
    
    if (!data || !data.chronicles || data.chronicles.length === 0) {
        container.innerHTML = '<div class="loading">No chronicles recorded yet. The Sentinel awaits...</div>';
        return;
    }

    let html = '';
    
    // Sort by date (newest first)
    const sorted = [...data.chronicles].sort((a, b) => {
        return new Date(b.created_at) - new Date(a.created_at);
    });

    sorted.forEach(chronicle => {
        const severity = getSeverityLevel(chronicle.severity);
        const date = formatDate(chronicle.created_at);
        
        html += `
            <div class="chronicle-card">
                <div class="chronicle-header">
                    <span class="severity-badge severity-${severity.level}">
                        ${severity.label} ${chronicle.severity}
                    </span>
                    <span style="color: #8888aa; font-size: 0.9rem;">
                        ${date}
                    </span>
                </div>
                <h2 class="chronicle-title">${chronicle.title || 'Untitled Chronicle'}</h2>
                <div class="chronicle-meta">
                    <span>📍 ${chronicle.region || 'Unknown'}</span>
                    <span>🔍 ${chronicle.finding_type || 'GuardDuty Finding'}</span>
                </div>
                <div class="chronicle-content">
                    ${chronicle.chronicle || 'No chronicle text available.'}
                </div>
            </div>
        `;
    });

    container.innerHTML = html;

    // Update stats
    document.getElementById('total-count').textContent = sorted.length;
    if (sorted.length > 0) {
        document.getElementById('latest-severity').textContent = `Severity ${sorted[0].severity}`;
    }
    if (data.style_memory) {
        document.getElementById('style-memory').textContent = data.style_memory.substring(0, 60) + '...';
    }
}

// Initialize the page
async function init() {
    const container = document.getElementById('chronicles-container');
    container.innerHTML = '<div class="loading">The Sentinel awakens...</div>';

    try {
        const data = await fetchChronicles();
        renderChronicles(data);
    } catch (error) {
        console.error('Failed to initialize:', error);
        container.innerHTML = `<div class="error">⚔️ The Sentinel cannot reach the archive. Please check your connection.</div>`;
    }

    // Refresh every 30 seconds
    setInterval(async () => {
        try {
            const data = await fetchChronicles();
            renderChronicles(data);
        } catch (error) {
            console.error('Refresh failed:', error);
        }
    }, 30000);
}

// Start when DOM is ready
document.addEventListener('DOMContentLoaded', init);