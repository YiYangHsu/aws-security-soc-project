exports.handler = async (event) => {

    const securityEvent = {
        eventType: "API_REQUEST",
        timestamp: new Date().toISOString(),
        sourceIP: event.requestContext?.http?.sourceIp || "unknown",
        route: event.rawPath || "unknown",
        userAgent: event.headers?.["user-agent"] || "unknown"
    };

    console.log(JSON.stringify(securityEvent));

    return {
        statusCode: 200,
        body: JSON.stringify({
            message: "AWS SOC Demo API is running",
            securityEvent
        })
    };
};

