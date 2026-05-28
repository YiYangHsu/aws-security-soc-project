exports.handler = async (event) => {
    console.log("Full event:", JSON.stringify(event, null, 2));
    
    const securityEvent = {
        eventType: "API_REQUEST",
        timestamp: new Date().toISOString(),
        sourceIP: event.requestContext?.http?.sourceIp || 
                  event.requestContext?.identity?.sourceIp || 
                  event.headers?.["x-forwarded-for"]?.split(",")[0]?.trim() ||
                  "unknown",
        route: event.requestContext?.http?.path || 
               event.rawPath || 
               event.path || 
               "unknown",
        userAgent: event.headers?.["user-agent"] || 
                   event.headers?.["User-Agent"] ||
                   "unknown",
        method: event.requestContext?.http?.method || event.httpMethod || "unknown"
    };

    // Log just the event type string for the metric filter
    console.log("API_REQUEST");
    console.log(JSON.stringify(securityEvent));

    // Suspicious User Agent Detection
    if (
        securityEvent.userAgent.toLowerCase().includes("curl") ||
        securityEvent.userAgent.toLowerCase().includes("python") ||
        securityEvent.userAgent.toLowerCase().includes("postman")
    ) {
        console.log("SUSPICIOUS_USER_AGENT");
        console.log(JSON.stringify({
            eventType: "SUSPICIOUS_USER_AGENT",
            severity: "MEDIUM",
            userAgent: securityEvent.userAgent,
            sourceIP: securityEvent.sourceIP,
            timestamp: new Date().toISOString()
        }));
    }

    // Simulate Lambda error for testing
    if (event.queryStringParameters?.testError === "true") {
        throw new Error("Simulated security incident error");
    }

    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "AWS SOC Demo API is running",
            securityEvent
        })
    };
};
//Compress-Archive -Path index.js -DestinationPath function.zip -Force