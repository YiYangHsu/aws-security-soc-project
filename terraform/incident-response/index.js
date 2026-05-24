exports.handler = async (event) => {

    console.log("=== SECURITY INCIDENT RECEIVED ===");

    console.log(JSON.stringify(event, null, 2));

    const incidentRecord = {
        incidentTime: new Date().toISOString(),
        severity: "HIGH",
        incidentType: "High API Request Volume",
        automatedAction: "Simulated response executed",
        status: "INVESTIGATING"
    };

    console.log("Incident Record:");
    console.log(JSON.stringify(incidentRecord, null, 2));

    console.log("=== AUTOMATED RESPONSE COMPLETED ===");

    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "Incident response executed",
            incidentRecord
        })
    };
};
//Compress-Archive -Path index.js -DestinationPath function.zip -Force
