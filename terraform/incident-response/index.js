exports.handler = async (event) => {
    console.log("=== SECURITY INCIDENT RECEIVED ===");
    console.log("Event type:", typeof event);
    console.log("Has Records:", !!event.Records);
    console.log("Full event:", JSON.stringify(event, null, 2));
    
    let incidentData = {};
    
    // Check if this is an SNS event
    if (event.Records && event.Records[0] && event.Records[0].Sns) {
        console.log("Processing SNS message");
        
        // Parse the SNS message (it's a JSON string)
        const snsMessage = JSON.parse(event.Records[0].Sns.Message);
        console.log("Parsed SNS Message:", JSON.stringify(snsMessage, null, 2));
        
        incidentData = {
            incidentTime: new Date().toISOString(),
            severity: snsMessage.AlarmName?.includes("Suspicious") ? "MEDIUM" : "HIGH",
            incidentType: snsMessage.AlarmName || "Unknown Alarm",
            alarmDescription: snsMessage.AlarmDescription || "No description",
            triggerReason: snsMessage.NewStateReason || "Unknown",
            oldState: snsMessage.OldStateValue || "Unknown",
            currentState: snsMessage.NewStateValue || "Unknown",
            alarmDetails: snsMessage,
            automatedAction: "Security incident logged for investigation",
            status: "INVESTIGATING"
        };
    } 
    // Handle direct test invocation
    else {
        console.log("Processing direct invocation (not SNS)");
        incidentData = {
            incidentTime: new Date().toISOString(),
            severity: "INFO",
            incidentType: "Direct Test",
            automatedAction: "Test execution",
            status: "TEST"
        };
    }
    
    console.log("=== INCIDENT RECORD ===");
    console.log(JSON.stringify(incidentData, null, 2));
    console.log("=== AUTOMATED RESPONSE COMPLETED ===");
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "Incident response executed",
            incidentRecord: incidentData
        })
    };
};